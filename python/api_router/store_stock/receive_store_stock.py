from fastapi import APIRouter, Depends, Form
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from api_router.employee.auth_employee import get_db, require_store
from api_router.office_stock.stock_common import SEND, STORE, store_doc_id

router = APIRouter()


# 수령 대기 중인 발송 목록 (자기 대리점 것만)
@router.get("")
async def incoming_store_stock(employee: dict = Depends(require_store)):

    try:
        docs = get_db().collection(SEND).where(
            filter=FieldFilter('store_seq', '==', employee['store_seq'])
        ).stream()
        rows = []
        for d in docs:
            row = d.to_dict()
            if row.get('s_check') == 0:
                row['send_id'] = d.id
                rows.append(row)
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}


# 수령 확인: send의 s_check를 1로 바꾸고 대리점 재고를 증가 (한 트랜잭션)
@router.post("")
async def receive_store_stock(
    send_id: str = Form(...),
    employee: dict = Depends(require_store),
):
    try:
        db = get_db()
        send_ref = db.collection(SEND).document(send_id)

        @firestore.transactional
        def run(tx):
            snap = send_ref.get(transaction=tx)
            if not snap.exists:
                return 'send not found'
            send = snap.to_dict()
            # 다른 대리점의 발송은 수령 불가
            if send.get('store_seq') != employee['store_seq']:
                return 'send not found'
            if send.get('s_check') == 1:
                return 'already received'

            stock_ref = db.collection(STORE).document(store_doc_id(send['store_seq'], send['pr_id']))
            stock = stock_ref.get(transaction=tx)
            if stock.exists:
                tx.update(stock_ref, {'s_count': (stock.to_dict().get('s_count') or 0) + send['s_count']})
            else:
                tx.set(stock_ref, {
                    'store_seq': send['store_seq'], 's_name': send['s_name'],
                    'pr_id': send['pr_id'], 's_count': send['s_count'],
                })
            tx.update(send_ref, {'s_check': 1})
            return None

        error = run(db.transaction())
        if error:
            return {'result': 'Error', 'message': error}
        return {'result': 'OK', 'send_id': send_id}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
