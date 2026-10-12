from fastapi import APIRouter, Depends, Form
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from api_router.employee.auth_employee import get_db, require_hq
from db import connect
from .stock_common import OFFICE, SEND, now

router = APIRouter()


# 주문(purchase)에 대한 대리점 발송: 본사재고 감소와 send 기록을 한 트랜잭션으로 처리
# 대리점 재고 증가는 대리점이 수령 확인(s_check=1)할 때 처리
@router.post("")
async def send_office_stock(
    p_id: int = Form(...),
    employee: dict = Depends(require_hq),
):
    conn = None

    try:
        conn = connect()
        curs = conn.cursor()
        curs.execute(
            """
            SELECT p.store_seq, s.name, p.SKU, p.p_count
            FROM purchase p LEFT JOIN store s ON s.seq = p.store_seq
            WHERE p.p_id = %s
            """,
            (p_id,),
        )
        order = curs.fetchone()
        if order is None:
            return {'result': 'Error', 'message': 'order not found'}
        store_seq, s_name, pr_id, count = order

        db = get_db()
        # 같은 주문의 중복 발송 방지
        dup = db.collection(SEND).where(filter=FieldFilter('p_id', '==', p_id)).limit(1).get()
        if len(dup) > 0:
            return {'result': 'Error', 'message': 'already sent'}

        stock_ref = db.collection(OFFICE).document(pr_id)
        send_ref = db.collection(SEND).document()

        @firestore.transactional
        def run(tx):
            snap = stock_ref.get(transaction=tx)
            have = (snap.to_dict() or {}).get('now_count', 0) if snap.exists else 0
            if have < count:
                return None
            tx.update(stock_ref, {'now_count': have - count})
            tx.set(send_ref, {
                'e_id': employee['e_id'], 'p_id': p_id, 'store_seq': store_seq,
                's_name': s_name, 'pr_id': pr_id, 's_count': count,
                's_date': now(), 's_check': 0,
            })
            return have - count

        left = run(db.transaction())
        if left is None:
            return {'result': 'Error', 'message': 'not enough stock'}
        return {'result': 'OK', 'send_id': send_ref.id, 'now_count': left}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
