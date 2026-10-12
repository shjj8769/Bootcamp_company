# python/APIRouter/payment/delete.py
# 결제 삭제 API → DELETE /payment/{seq}
# 주소로 결제번호만 받으므로 BaseModel class 없음
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


@router.delete("/{seq}")
def delete_payment(seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = "DELETE FROM payment WHERE seq = %s"
            curs.execute(sql, (seq,))
            # rowcount: 삭제된 행 수 → 0이면 해당 결제번호가 없음
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="삭제할 결제 내역이 없습니다")
        conn.commit()  # 실제 DB에 삭제 확정
        return {"result": "OK"}
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        conn.rollback()  # 에러 시 삭제 취소
        raise HTTPException(status_code=500, detail=f"결제 삭제 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
