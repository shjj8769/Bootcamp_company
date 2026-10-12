from fastapi import APIRouter, Depends

from api_router.employee.auth_employee import get_db, require_hq
from api_router.office_stock.stock_common import BASE_COUNT, LEAST_COUNT, OFFICE, need_order
from db import connect
from .approval_common import APPROVAL, REQUEST, STATE_ORDERED, merge, new_cache, public_view, real_docs

router = APIRouter()


# 내 부서의 품의 목록 (본사 직원 전용, 최신순). 품의서와 품의를 올리다 문서를 합쳐서 내려주고,
# 결재선과 신청자 부서/직급은 main_server에서 계산함. 각 품의에 내가 서명/발주할 수 있는지(can_sign, can_order)도 함께 줌
@router.get("")
async def list_approval(employee: dict = Depends(require_hq)):

    try:
        approvals = {d.id: d.to_dict() for d in real_docs(APPROVAL)}
        cache = new_cache()
        rows = []
        for doc in real_docs(REQUEST):
            approval = approvals.get(doc.id)
            if approval is None:
                continue
            data = merge(doc.id, approval, doc.to_dict(), cache)
            if data['e_team'] == employee['e_team']:
                rows.append(public_view(data, employee))
        rows.sort(key=lambda r: r['a_seq'], reverse=True)
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}


# 발주 품의 작성 시 선택할 제조사 목록
@router.get("/manufacture")
async def list_manufacture(employee: dict = Depends(require_hq)):

    try:
        rows = [
            {'m_id': d.to_dict().get('m_id', d.id), 'm_name': d.to_dict().get('m_name')}
            for d in get_db().collection('manufacture').stream()
            if d.id != '_erd'
        ]
        rows.sort(key=lambda r: str(r['m_id']))
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}


# 발주 품의 후보: 본사재고를 재고가 적은 순서대로 보여줌 (재고 부족 = 최소수량 30% 미만이면 need_order)
# 제조사는 제품(MySQL product)의 브랜드와 같은 이름의 제조사를 자동으로 찾아 m_id/m_name으로 내려줌 (없으면 None)
# 수량은 기준재고(100)까지 채우는 값(suggested_count)을 제안하고, 같은 제품으로 진행 중인 품의가 있으면 pending=true
@router.get("/candidates")
async def list_candidates(employee: dict = Depends(require_hq)):

    conn = None

    try:
        db = get_db()
        conn = connect()
        curs = conn.cursor()
        curs.execute("SELECT SKU, pr_brand FROM product")
        brand_of = dict(curs.fetchall())

        manufactures = {}
        for d in db.collection('manufacture').stream():
            if d.id == '_erd':
                continue
            m = d.to_dict()
            manufactures[str(m.get('m_name'))] = m
            manufactures.setdefault(str(m.get('m_id', d.id)), m)

        # 발주가 끝나지 않은(심사중, 심사완료) 품의에 들어 있는 제품
        approvals = {d.id: d.to_dict() for d in real_docs(APPROVAL)}
        pending = set()
        for r in real_docs(REQUEST):
            if r.to_dict().get('a_state') != STATE_ORDERED:
                for item in (approvals.get(r.id) or {}).get('a_items', []):
                    pending.add(item.get('pr_id'))

        rows = []
        for d in db.collection(OFFICE).stream():
            if d.id == '_erd':
                continue
            stock = d.to_dict()
            now = int(stock.get('now_count') or 0)
            m = manufactures.get(str(brand_of.get(d.id)))
            rows.append({
                'pr_id': d.id,
                'pr_name': stock.get('pr_name'),
                'now_count': now,
                'least_count': LEAST_COUNT,
                'base_count': BASE_COUNT,
                'need_order': need_order(now),
                'm_id': m.get('m_id') if m else None,
                'm_name': m.get('m_name') if m else None,
                'suggested_count': max(BASE_COUNT - now, 1),
                'pending': d.id in pending,
            })
        rows.sort(key=lambda r: (r['now_count'], r['pr_id']))
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
