# python/APIRouter/payment/search.py
# 결제 조회 API (고객 → 본사 결제 정보만 다룸, 구매 상품 정보는 purchase 폴더)
#   GET /payment/                          전체 결제 내역
#   GET /payment/customer/{email}          고객별 결제 내역
#   GET /payment/{seq}                     결제 1건
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 결제 공통 SELECT
# 여러 API가 같은 SELECT를 쓰므로 한 번만 작성하고 뒤에 WHERE/ORDER BY만 붙여서 사용
SELECT_SQL = """
    SELECT seq, email, e_id, pay_id, pay_date, pay_price
    FROM payment
"""


# DB 결과 한 줄을 응답 형식으로 변환 (번호는 SELECT_SQL 컬럼 순서)
# → SELECT_SQL의 컬럼을 추가하거나 순서를 바꾸면 여기 번호도 같이 수정해야 함
def to_dict(row):
    return {
        "seq": row[0],        # 결제 seq (PK)
        "email": row[1],      # 결제한 고객
        "e_id": row[2],       # 본사 직원
        "pay_id": row[3],     # 결제번호
        "pay_date": row[4],   # 결제일
        "pay_price": row[5],  # 결제금액
    }


# 전체 결제 내역 조회 (최신순)
@router.get("/")
def select_payments():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY pay_date DESC"
            curs.execute(sql)
            rows = curs.fetchall()  # 결과 전체를 튜플 목록으로 받음
        return {"results": [to_dict(row) for row in rows]}  # 한 줄씩 dict로 변환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()


# 고객별 결제 내역 조회 (최신순)
# 결제에 포함된 상품 목록은 GET /purchase/payment/{seq} 로 조회
@router.get("/customer/{email}")
def select_payments_by_customer(email: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE email = %s
                ORDER BY pay_date DESC
            """
            curs.execute(sql, (email,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()


# 결제 1건 조회
# 주의: "/customer/..." 보다 아래에 있어야 "customer"가 seq로 잘못 인식되지 않음
@router.get("/{seq}")
def select_payment(seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE seq = %s"
            curs.execute(sql, (seq,))  # 값이 1개여도 튜플이라 (seq,) 처럼 쉼표 필요
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
        if row is None:
            raise HTTPException(status_code=404, detail="결제 내역이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()
