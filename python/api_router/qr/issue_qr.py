import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Form

from db import connect
from . import qr_memory

router = APIRouter()


# 고객이 결제 후 매장에 왔을 때 픽업 QR 난수 발급 (고객 앱에서 호출)
# 호출할 때마다 새 난수를 만들고, 같은 주문의 이전 QR은 무효화
@router.post("")
async def issue_qr(
    p_id: int = Form(...),
    email: str = Form(...),
):
    conn = None

    try:
        if qr_memory.is_picked(p_id):
            return {'result': 'Error', 'message': 'already picked up'}

        conn = connect()
        curs = conn.cursor()
        # 결제된 주문(purchase)이고 주문자 이메일이 일치해야 발급
        curs.execute(
            "SELECT store_seq, SKU, p_count FROM purchase WHERE p_id = %s AND email = %s",
            (p_id, email.strip()),
        )
        order = curs.fetchone()
        if order is None:
            return {'result': 'Error', 'message': 'order not found'}

        code = secrets.token_urlsafe(16)
        qr_memory.save(code, {
            'p_id': p_id, 'email': email.strip(), 'store_seq': order[0],
            'pr_id': order[1], 'count': order[2] or 0,
        })
        expires_at = datetime.now(timezone.utc) + timedelta(seconds=qr_memory.QR_EXPIRE_SECONDS)
        return {'result': 'OK', 'code': code, 'expires_at': expires_at.isoformat()}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
