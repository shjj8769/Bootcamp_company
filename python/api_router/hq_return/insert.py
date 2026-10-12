# python/APIRouter/hq_return/insert.py
# 반납 등록 API → POST /hq_return/
# 고객이 대리점에 반품한 제품을, 대리점이 본사로 반납할 때 기록 (return 테이블)
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# return 테이블 형식에 맞춘 요청 바디
# BaseModel: 값이 빠졌거나 타입이 틀리면 함수 실행 전에 422 에러를 자동으로 돌려줌
class HqReturn(BaseModel):
    e_id: str                            # 반납 처리한 직원 예: SALES-002
    p_id: Optional[int] = None           # 반납id (AUTO_INCREMENT) → 비워두면 DB가 다음 번호로 자동 생성
    p_date: Optional[datetime] = None    # 비어 있으면 현재 시각으로 저장
    email: str                           # 반품했던 고객 (customer.email)
    SKU: str                             # 반납하는 제품 (product.SKU)
    store_seq: int                       # 반납하는 대리점


@router.post("/")
def insert_hq_return(hq_return: HqReturn):
    conn = connect()  # DB 연결
    try:
        with conn.cursor() as curs:
            # return은 MySQL 예약어라 테이블 이름을 `return` 처럼 백틱으로 감싸야 함
            # 컬럼 순서는 DB 순서와 동일 (e_id, p_id, p_date, email, SKU, store_seq)
            sql = """
                INSERT INTO `return`
                    (e_id, p_id, p_date, email, SKU, store_seq)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                hq_return.e_id,
                hq_return.p_id,  # None이면 AUTO_INCREMENT 컬럼에 NULL → DB가 다음 번호 자동 부여
                hq_return.p_date or datetime.now(),  # 날짜가 없으면 지금 시각
                hq_return.email,
                hq_return.SKU,
                hq_return.store_seq,
            ))
            p_id = curs.lastrowid  # 방금 생성(또는 입력)된 반납id
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK", "p_id": p_id}
    except Exception as e:
        conn.rollback()  # 에러 시 저장하지 않고 되돌림
        raise HTTPException(status_code=500, detail=f"반납 등록 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
