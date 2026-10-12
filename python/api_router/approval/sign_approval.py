from fastapi import APIRouter, Depends, Form
from google.cloud import firestore

from api_router.employee.auth_employee import get_db, require_hq
from .approval_common import APPROVAL, REQUEST, STATE_DONE, can_sign, merge, new_cache, now

router = APIRouter()


# 결재(서명): 현재 차례의 결재자(같은 부서의 팀장 -> 임원 순서)만 가능. 서명할 때마다 처리일(a_date)이 갱신되고 결재순서(a_step)가 올라감
# 마지막 결재자가 서명하면 a_state가 '심사완료'가 됨
@router.post("")
async def sign_approval(a_seq: int = Form(...), employee: dict = Depends(require_hq)):

    try:
        db = get_db()
        approval_ref = db.collection(APPROVAL).document(str(a_seq))
        request_ref = db.collection(REQUEST).document(str(a_seq))
        approval = approval_ref.get()

        @firestore.transactional
        def run(tx):
            request = request_ref.get(transaction=tx)
            if not approval.exists or not request.exists:
                return 'approval not found'
            data = merge(str(a_seq), approval.to_dict(), request.to_dict(), new_cache())
            if not can_sign(data, employee):
                return 'not your turn'
            signed_at = now()
            step = data.get('a_step') or 1
            update = {
                'a_signatures': (data.get('a_signatures') or []) + [{
                    'e_id': employee['e_id'],
                    'e_jobtitle': employee['e_jobtitle'],
                    'signed_at': signed_at,
                }],
                'a_step': step + 1,
                'a_date': signed_at,
            }
            if step >= len(data['a_line']):
                update['a_state'] = STATE_DONE
            tx.update(request_ref, update)
            return None

        error = run(db.transaction())
        if error:
            return {'result': 'Error', 'message': error}
        return {'result': 'OK', 'a_seq': a_seq}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
