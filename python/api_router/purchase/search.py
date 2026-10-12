# python/APIRouter/purchase/search.py
# 구매 조회 API (구매 항목 + 제품 정보)
#   GET /purchase/                     전체 구매 내역
#   GET /purchase/customer/{email}     고객별 구매 내역
#   GET /purchase/payment/{p_seq}      결제 1건에 포함된 상품 목록
#   GET /purchase/{p_id}               구매 1건
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 구매 + 제품 정보를 함께 조회하는 공통 SELECT (구매 컬럼 순서는 DB 순서와 동일)
# purchase.SKU = product.SKU 로 제품 정보를 가져옴 (SKU = 사이즈별 고유 코드)
# LEFT JOIN: 제품 정보가 없어도 구매 내역은 빠지지 않고 나옴 (제품 값은 None)
# 여러 API가 같은 SELECT를 쓰므로 한 번만 작성하고 뒤에 WHERE/ORDER BY만 붙여서 사용
# pur / pro 는 테이블 별칭 (purchase / product)
SELECT_SQL = """
    SELECT pur.p_id, pur.p_seq, pur.p_count, pur.p_date, pur.p_price,
        pur.email, pur.SKU, pur.store_seq,
        pro.pr_name, pro.pr_brand, pro.size, pro.color
    FROM purchase pur
    LEFT JOIN product pro
        ON pro.SKU = pur.SKU
"""


# DB 결과 한 줄을 응답 형식으로 변환 (번호는 SELECT_SQL 컬럼 순서)
# → SELECT_SQL의 컬럼을 추가하거나 순서를 바꾸면 여기 번호도 같이 수정해야 함
def to_dict(row):
    return {
        "p_id": row[0],        # 구매번호
        "p_seq": row[1],       # 결제번호 (payment.seq)
        "p_count": row[2],     # 구매수량
        "p_date": row[3],      # 구매일
        "p_price": row[4],     # 구매가격
        "email": row[5],       # 고객
        "SKU": row[6],         # 제품 고유 코드
        "store_seq": row[7],   # 수령 대리점
        "pr_name": row[8],     # 제품명
        "pr_brand": row[9],    # 브랜드명
        "size": row[10],       # 사이즈
        "color": row[11],      # 색상
    }


# 전체 구매 내역 조회 (최신순)
@router.get("/")
def select_purchases():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY pur.p_date DESC"
            curs.execute(sql)
            rows = curs.fetchall()  # 결과 전체를 튜플 목록으로 받음
        return {"results": [to_dict(row) for row in rows]}  # 한 줄씩 dict로 변환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"구매 조회 실패: {e}")
    finally:
        conn.close()


# 고객별 구매 내역 조회 (최신순) → 사용자 앱 "내 구매내역" 화면
@router.get("/customer/{email}")
def select_purchases_by_customer(email: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE pur.email = %s
                ORDER BY pur.p_date DESC
            """
            curs.execute(sql, (email,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"구매 조회 실패: {e}")
    finally:
        conn.close()


# 결제 1건에 포함된 상품 목록 조회 → 결제 상세 화면
@router.get("/payment/{p_seq}")
def select_purchases_by_payment(p_seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE pur.p_seq = %s
                ORDER BY pur.p_id
            """
            curs.execute(sql, (p_seq,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"구매 조회 실패: {e}")
    finally:
        conn.close()


# 구매 1건 조회
# 주의: "/customer/...", "/payment/..." 보다 아래에 있어야 주소가 p_id로 잘못 인식되지 않음
@router.get("/{p_id}")
def select_purchase(p_id: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE pur.p_id = %s"
            curs.execute(sql, (p_id,))
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
        if row is None:
            raise HTTPException(status_code=404, detail="구매 내역이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"구매 조회 실패: {e}")
    finally:
        conn.close()
