from datetime import datetime, timezone

from fastapi import APIRouter

from . import qr_memory

router = APIRouter()


# 고객 앱이 내 주문에 대해 대리점이 생성한 현재 유효한 QR 코드를 가져옴 (주문번호 + 주문한 이메일 일치 필요)
# 코드가 없거나 만료됐거나 이메일이 다르면 모두 같은 'no active qr'로 응답하고, 고객 앱은 몇 초마다 다시 물어봄(폴링)
@router.get("")
async def active_qr(p_id: int, email: str):

    try:
        if qr_memory.is_picked(p_id):
            return {'result': 'Error', 'message': 'already picked up'}

        found = qr_memory.find_by_order(p_id)
        if found is None or found[1]['email'] != email.strip():
            return {'result': 'Error', 'message': 'no active qr'}

        code, info = found
        expires_at = datetime.fromtimestamp(info['expires_at'], timezone.utc)
        return {'result': 'OK', 'code': code, 'expires_at': expires_at.isoformat()}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
