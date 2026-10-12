import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Form

from api_router.employee.auth_employee import require_store
from db import connect
from . import qr_memory

router = APIRouter()


# 고객이 매장에 왔을 때 대리점 직원이 주문을 골라 픽업 QR 난수를 생성 (대리점 로그인 필요)
# 생성된 QR은 고객 앱이 GET /qr/active로 가져가 같은 QR을 보여주고, 대리점이 스캔해서 인증함
# 호출할 때마다 새 난수를 만들고, 같은 주문의 이전 QR은 무효화. 자기 매장(store_seq) 주문만 생성 가능
@router.post("")
async def issue_qr(
    p_id: int = Form(...),
    employee: dict = Depends(require_store),
):
    conn = None

    try:
        if qr_memory.is_picked(p_id):
            return {'result': 'Error', 'message': 'already picked up'}

        conn = connect()
        curs = conn.cursor()
        # 결제된 주문(purchase)이고 이 대리점에서 받는 주문이어야 생성 (고객 이메일은 주문에서 가져옴)
        curs.execute(
            "SELECT email, SKU, p_count FROM purchase WHERE p_id = %s AND store_seq = %s",
            (p_id, employee['store_seq']),
        )
        order = curs.fetchone()
        if order is None:
            return {'result': 'Error', 'message': 'order not found'}

        code = secrets.token_urlsafe(16)
        qr_memory.save(code, {
            'p_id': p_id, 'email': order[0], 'store_seq': employee['store_seq'],
            'pr_id': order[1], 'count': order[2] or 0,
        })
        expires_at = datetime.fromtimestamp(qr_memory.get(code)['expires_at'], timezone.utc)
        return {
            'result': 'OK', 'code': code, 'expires_at': expires_at.isoformat(),
            'p_id': p_id, 'email': order[0], 'pr_id': order[1], 'count': order[2] or 0,
        }

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
