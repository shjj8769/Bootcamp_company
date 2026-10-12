# python/APIRouter/payment/insert.py
# 결제 등록 API → POST /payment/
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

# 이 파일의 API들을 담는 라우터 (__init__.py에서 payment_router로 묶임)
router = APIRouter()


# 결제 등록 시 앱이 보내야 하는 값 (payment 테이블 형식)
# BaseModel: 값이 빠졌거나 타입이 틀리면 함수 실행 전에 422 에러를 자동으로 돌려줌
class Payment(BaseModel):
    email: str                           # 결제한 고객 (customer.email)
    e_id: str                            # 결제받는 본사 직원 (employee.e_id)
    pay_id: str                          # 결제번호
    pay_date: Optional[datetime] = None  # 비어 있으면 현재 시각으로 저장
    pay_price: int                       # 결제 금액
    # seq(결제번호)는 DB가 AUTO_INCREMENT로 자동 생성하므로 받지 않음


@router.post("/")
def insert_payment(payment: Payment):
    conn = connect()  # DB 연결
    try:
        with conn.cursor() as curs:  # SQL을 실행할 커서 (with가 끝나면 자동으로 닫힘)
            # %s 자리에 값이 순서대로 들어감 (SQL 인젝션 방지)
            sql = """
                INSERT INTO payment
                    (email, e_id, pay_id, pay_date, pay_price)
                VALUES (%s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                payment.email,
                payment.e_id,
                payment.pay_id,
                payment.pay_date or datetime.now(),  # 날짜가 없으면 지금 시각
                payment.pay_price,
            ))
            seq = curs.lastrowid  # 방금 INSERT로 생성된 결제번호
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK", "seq": seq}  # 앱은 이 seq로 조회/수정/삭제
    except Exception as e:
        conn.rollback()  # 에러 시 저장하지 않고 되돌림
        raise HTTPException(status_code=500, detail=f"결제 등록 실패: {e}")
    finally:
        conn.close()  # 성공/실패 상관없이 DB 연결 종료
