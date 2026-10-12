from fastapi import APIRouter, Depends, Form
from google.cloud import firestore

from api_router.employee.auth_employee import get_db, require_store
from api_router.office_stock.stock_common import STORE, store_doc_id
from db import connect
from . import qr_memory

router = APIRouter()


# 매장 직원이 카메라로 QR을 스캔해 픽업 인증: 대리점 재고 차감, QR 사용 처리, pick_up 기록
@router.post("")
async def scan_qr(
    code: str = Form(...),
    employee: dict = Depends(require_store),
):
    conn = None

    try:
        code = code.strip()
        # 없거나 만료된 코드, 다른 대리점의 주문 QR은 같은 에러로 응답
        info = qr_memory.get(code)
        if info is None or info['store_seq'] != employee['store_seq']:
            return {'result': 'Error', 'message': 'invalid or expired qr'}

        # pick_up 기록은 재고 차감이 성공한 뒤에 커밋
        conn = connect()
        curs = conn.cursor()
        curs.execute(
            "INSERT INTO pick_up (e_id, p_date, email, SKU, store_seq) VALUES (%s, NOW(), %s, %s, %s)",
            (employee['e_id'], info['email'], info['pr_id'], info['store_seq']),
        )

        db = get_db()
        stock_ref = db.collection(STORE).document(store_doc_id(info['store_seq'], info['pr_id']))

        @firestore.transactional
        def run(tx):
            stock = stock_ref.get(transaction=tx)
            have = (stock.to_dict() or {}).get('s_count', 0) if stock.exists else 0
            if have < info['count']:
                return 'not enough stock'
            tx.update(stock_ref, {'s_count': have - info['count']})
            return None

        error = run(db.transaction())
        if error:
            conn.rollback()
            return {'result': 'Error', 'message': error}

        conn.commit()
        qr_memory.use(code)
        return {'result': 'OK', 'p_id': info['p_id'], 'pr_id': info['pr_id'], 'count': info['count']}

    except Exception as e:
        if conn is not None:
            conn.rollback()
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
