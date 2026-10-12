import os

from dotenv import load_dotenv
from fastapi import APIRouter
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

load_dotenv()

router = APIRouter()

# 부가세율 10%
VAT_RATE = 0.1

# 견적서는 Firebase(Firestore)에서 관리한다.
# estimate 문서 1개 = 견적서의 품목 1행이며, 문서 생성은 품의(결제) 승인 처리에서 한다.
# e_seq는 행 고유번호, e_e_seq는 같은 견적서의 품목 행들이 공유하는 견적서 묶음 번호
# 제조사(m_id)는 order 컬렉션이 e_seq로 estimate와 연결한다.
# 견적번호: 'MQ-' + 견적일(YYMMDD) + '-' + e_e_seq(3자리)  예) MQ-260923-030
# 견적서와 주문서(영수증)는 동일하게 취급한다. (추후 주문서 코드와 병합 예정)

_db = None


def get_db():
    global _db
    if _db is None:
        _db = firestore.Client(project=os.getenv('FIREBASE_PROJECT_ID'))
    return _db


# 컬렉션의 문서를 dict 리스트로 반환 (구조 정의 문서 _erd 제외)
def read_docs(query):
    return [doc.to_dict() for doc in query.stream() if doc.id != '_erd']


def date_str(value):
    if value is None:
        return None
    if hasattr(value, 'strftime'):
        return value.strftime('%Y-%m-%d')
    return str(value)[:10]


def estimate_no(e_date, e_e_seq):
    ymd = date_str(e_date).replace('-', '')[2:8]
    return 'MQ-{}-{:03d}'.format(ymd, int(e_e_seq))


# order 컬렉션에서 e_seq -> m_id 매핑
def order_m_ids():
    return {o.get('e_seq'): o.get('m_id') for o in read_docs(get_db().collection('order'))}


# manufacture 컬렉션에서 m_id -> 제조사 정보 매핑
def manufactures():
    return {m.get('m_id'): m for m in read_docs(get_db().collection('manufacture'))}


def calc_price(supply):
    vat = int(supply * VAT_RATE)
    return {'supply_price': supply, 'vat': vat, 'total_price': supply + vat}


# 견적서 목록: e_e_seq 기준 한 장당 한 줄, 최신 견적서부터 조회
@router.get("/list")
async def list_estimate():

    try:
        items = read_docs(get_db().collection('estimate'))
        m_by_seq = order_m_ids()
        m_info = manufactures()

        groups = {}
        for item in items:
            groups.setdefault(item.get('e_e_seq'), []).append(item)

        results = []
        for e_e_seq, rows in groups.items():
            e_date = min(r['e_date'] for r in rows if r.get('e_date') is not None)
            m_id = next((m_by_seq[r.get('e_seq')] for r in rows if r.get('e_seq') in m_by_seq), None)
            supply = sum(int(r.get('e_price') or 0) for r in rows)
            results.append({
                'e_e_seq': e_e_seq,
                'estimate_no': estimate_no(e_date, e_e_seq),
                'm_id': m_id,
                'm_name': m_info.get(m_id, {}).get('m_name'),
                'e_date': date_str(e_date),
                **calc_price(supply),
            })
        results.sort(key=lambda r: r['e_e_seq'], reverse=True)
        return {'results': results}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}


# 견적서 상세: 같은 e_e_seq의 품목 행들을 e_seq 순서로 조회
@router.get("/detail")
async def detail_estimate(e_e_seq: int):

    try:
        rows = read_docs(get_db().collection('estimate').where(filter=FieldFilter('e_e_seq', '==', e_e_seq)))
        if not rows:
            return {'result': 'Error', 'message': 'estimate not found'}
        rows.sort(key=lambda r: r.get('e_seq') or 0)

        m_by_seq = order_m_ids()
        m_id = next((m_by_seq[r.get('e_seq')] for r in rows if r.get('e_seq') in m_by_seq), None)
        manufacture = manufactures().get(m_id, {})

        # 순번은 DB 필드가 아니라 행 순서대로 계산
        items = [
            {
                'no': no,
                'e_seq': r.get('e_seq'),
                'pr_id': r.get('pr_id'),
                'pr_name': r.get('pr_name'),
                'e_list_price': r.get('e_list_price'),
                'e_count': r.get('e_count'),
                'e_price': r.get('e_price'),
            }
            for no, r in enumerate(rows, start=1)
        ]
        e_date = rows[0].get('e_date')
        supply = sum(int(r.get('e_price') or 0) for r in rows)
        return {
            'estimate_no': estimate_no(e_date, e_e_seq),
            'e_e_seq': e_e_seq,
            'e_date': date_str(e_date),
            'm_id': m_id,
            'm_name': manufacture.get('m_name'),
            'm_address': manufacture.get('m_address'),
            'items': items,
            **calc_price(supply),
        }

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
