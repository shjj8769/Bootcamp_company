# python/APIRouter/refund/update.py
# 환불 처리 API → PUT /refund/{p_r_id}
# 대리점/본사 직원이 반품을 확인하고 환불 완료로 바꿀 때 사용
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 반품 처리 상태 변경 (p_r_id는 주소로 받음)
class RefundUpdate(BaseModel):
    is_refunded: int                # 0: 환불 전, 1: 환불 완료
    e_id: Optional[str] = None      # 처리한 직원 (비어 있으면 기존 값 유지)


@router.put("/{p_r_id}")
def update_refund(p_r_id: int, refund: RefundUpdate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            # COALESCE(새 값, 기존 값): 새 값이 None이면 기존 e_id를 그대로 둠
            sql = """
                UPDATE p_return
                SET is_refunded = %s, e_id = COALESCE(%s, e_id)
                WHERE p_r_id = %s
            """
            curs.execute(sql, (
                refund.is_refunded,
                refund.e_id,
                p_r_id,
            ))
            # rowcount: 바뀐 행 수 → 0이면 해당 반품id가 없음
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="수정할 반품 내역이 없습니다")
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK"}
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        conn.rollback()  # 에러 시 변경 내용 되돌림
        raise HTTPException(status_code=500, detail=f"반품 수정 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
