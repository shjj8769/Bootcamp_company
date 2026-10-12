from fastapi import APIRouter, Depends
from google.api_core.exceptions import AlreadyExists
from google.cloud import firestore
from pydantic import BaseModel, Field

from api_router.employee.auth_employee import get_db, require_hq
from .approval_common import (
    APPROVAL, REQUEST, STATE_DONE, STATE_REVIEW, has_executive, make_line, now, real_docs,
)

router = APIRouter()


class ApprovalItem(BaseModel):
    pr_id: str
    pr_name: str = ''
    e_count: int = Field(gt=0)
    e_list_price: int = Field(ge=0)


class ApprovalSubmit(BaseModel):
    m_id: str
    a_reason: str = ''
    items: list[ApprovalItem] = Field(min_length=1)


# 발주 품의 상신 (본사 직원). 품의서(approval)와 품의를 올리다(approval_request) 문서가 함께 만들어짐
# 결재선(사원 -> 팀장 -> 임원)은 저장하지 않고 계산하며 '심사중'이 됨. 결재선은 항상 임원으로 끝나야 하며(임원이 없는 부서는 거부),
# 신청자가 임원이면 바로 '심사완료'가 되어 본인이 발주할 수 있음
@router.post("")
async def submit_approval(body: ApprovalSubmit, employee: dict = Depends(require_hq)):

    try:
        db = get_db()
        manufacture = db.collection('manufacture').document(body.m_id).get()
        if not manufacture.exists:
            return {'result': 'Error', 'message': 'manufacture not found'}
        a_name = (manufacture.to_dict() or {}).get('m_name') or body.m_id

        line = make_line(employee)
        if not has_executive(employee, line):
            return {'result': 'Error', 'message': 'no executive in team'}

        # a_seq는 기존 최대값 + 1. 동시에 같은 번호를 만들면 create가 실패하므로 다시 계산해 재시도
        for _ in range(3):
            a_seq = max([int(d.id) for d in real_docs(APPROVAL)] + [0]) + 1
            try:
                @firestore.transactional
                def run(tx):
                    tx.create(db.collection(APPROVAL).document(str(a_seq)), {
                        'a_seq': a_seq,
                        'a_reason': body.a_reason.strip(),
                        'a_name': a_name,
                        'a_items': [item.model_dump() for item in body.items],
                    })
                    tx.create(db.collection(REQUEST).document(str(a_seq)), {
                        'e_id': employee['e_id'],
                        'a_seq': a_seq,
                        'a_signatures': [],
                        'a_date': now(),
                        'a_step': 1,
                        'a_state': STATE_REVIEW if line else STATE_DONE,
                    })

                run(db.transaction())
                return {'result': 'OK', 'a_seq': a_seq}
            except AlreadyExists:
                continue
        return {'result': 'Error', 'message': 'try again'}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
