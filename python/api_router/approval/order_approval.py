from fastapi import APIRouter, Depends, Form
from google.api_core.exceptions import AlreadyExists
from google.cloud import firestore

from api_router.employee.auth_employee import get_db, require_hq
from .approval_common import (
    APPROVAL, REQUEST, STATE_ORDERED, can_order, merge, new_cache, now,
)

router = APIRouter()


# 발주: 심사완료된 품의를 마지막 결재자(임원)가 발주 처리하고 처리상태를 '발주완료'로 바꿈
# 견적서 1장 = estimate 문서(품목 1행씩, e_e_seq 공유)들 + 제조사 연결용 order 문서들을 한 번에 생성
# e_seq(행 번호), e_e_seq(견적서 번호)는 기존 estimate 데이터의 최대값에 이어서 채번.
# 동시에 같은 번호를 만들면 create가 실패하므로 번호를 다시 계산해 재시도
@router.post("")
async def order_approval(a_seq: int = Form(...), employee: dict = Depends(require_hq)):

    try:
        db = get_db()
        approval_ref = db.collection(APPROVAL).document(str(a_seq))
        request_ref = db.collection(REQUEST).document(str(a_seq))
        approval = approval_ref.get()
        if not approval.exists or not request_ref.get().exists:
            return {'result': 'Error', 'message': 'approval not found'}

        # 제조사 이름(a_name)으로 order에 저장할 제조사 ID(m_id)를 찾음
        a_name = approval.to_dict().get('a_name')
        m_id = a_name
        for m in db.collection('manufacture').stream():
            if m.id != '_erd' and m.to_dict().get('m_name') == a_name:
                m_id = m.to_dict().get('m_id', m.id)

        for _ in range(3):
            base_seq = 0
            base_e_seq = 0
            for d in db.collection('estimate').stream():
                if d.id == '_erd':
                    continue
                row = d.to_dict()
                base_seq = max(base_seq, int(row.get('e_seq') or 0))
                base_e_seq = max(base_e_seq, int(row.get('e_e_seq') or 0))

            @firestore.transactional
            def run(tx):
                request = request_ref.get(transaction=tx)
                data = merge(str(a_seq), approval.to_dict(), request.to_dict(), new_cache())
                if data.get('a_state') == STATE_ORDERED:
                    return None, 'already ordered'
                if not can_order(data, employee):
                    return None, 'not allowed to order'

                e_seq = base_seq
                e_e_seq = base_e_seq + 1
                ordered_at = now()
                for item in data['a_items']:
                    e_seq += 1
                    tx.create(db.collection('estimate').document(str(e_seq)), {
                        'e_seq': e_seq,
                        'e_e_seq': e_e_seq,
                        'e_date': ordered_at,
                        'pr_id': item['pr_id'],
                        'pr_name': item.get('pr_name', ''),
                        'o_date': ordered_at,
                        'o_count': item['e_count'],
                        'e_count': item['e_count'],
                        'e_list_price': item['e_list_price'],
                        'e_price': item['e_list_price'] * item['e_count'],
                    })
                    tx.create(db.collection('order').document(str(e_seq)), {
                        'e_id': employee['e_id'],
                        'e_seq': e_seq,
                        'm_id': m_id,
                        'o_date': ordered_at,
                        'o_count': item['e_count'],
                        'pr_id': item['pr_id'],
                    })
                tx.update(request_ref, {'a_state': STATE_ORDERED, 'a_date': ordered_at})
                return e_e_seq, None

            try:
                e_e_seq, error = run(db.transaction())
            except AlreadyExists:
                continue
            if error:
                return {'result': 'Error', 'message': error}
            return {'result': 'OK', 'a_seq': a_seq, 'e_e_seq': e_e_seq}
        return {'result': 'Error', 'message': 'try again'}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
