from fastapi import APIRouter, Depends, Form
from google.cloud import firestore

from api_router.employee.auth_employee import get_db, require_hq
from db import connect
from .stock_common import LEAST_COUNT, OFFICE, RECEIPT, now

router = APIRouter()


# 제조사 수주: receipt 기록과 본사재고 증가를 한 트랜잭션으로 처리
@router.post("")
async def receive_office_stock(
    pr_id: str = Form(...),
    re_count: int = Form(...),
    m_id: int = Form(...),
    p_brand: str = Form(''),
    employee: dict = Depends(require_hq),
):
    if re_count <= 0:
        return {'result': 'Error', 'message': 'count must be positive'}

    conn = None

    try:
        # 신규 SKU면 본사재고 문서를 만들기 위해 상품 정보 조회
        conn = connect()
        curs = conn.cursor()
        curs.execute("SELECT pr_name, gender FROM product WHERE SKU = %s", (pr_id,))
        product = curs.fetchone()
        if product is None:
            return {'result': 'Error', 'message': 'product not found'}

        db = get_db()
        stock_ref = db.collection(OFFICE).document(pr_id)
        receipt_ref = db.collection(RECEIPT).document()

        @firestore.transactional
        def run(tx):
            snap = stock_ref.get(transaction=tx)
            before = (snap.to_dict() or {}).get('now_count', 0) if snap.exists else 0
            after = before + re_count
            if snap.exists:
                tx.update(stock_ref, {'now_count': after, 'least_count': LEAST_COUNT})
            else:
                tx.set(stock_ref, {
                    'p_id': pr_id, 'pr_name': product[0], 'pr_gender': product[1],
                    'now_count': after, 'least_count': LEAST_COUNT,
                })
            tx.set(receipt_ref, {
                'e_id': employee['e_id'], 'm_id': m_id, 're_date': now(),
                're_count': re_count, 'pr_id': pr_id,
                'p_count_now': after, 'p_brand': p_brand, 'P_r_date': now(),
            })
            return after

        after = run(db.transaction())
        return {'result': 'OK', 'pr_id': pr_id, 'now_count': after}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
