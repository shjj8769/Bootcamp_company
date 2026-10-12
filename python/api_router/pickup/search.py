# python/APIRouter/pickup/search.py
# 수령 조회 API
#   GET /pickup/                       전체 수령 내역 (본사용)
#   GET /pickup/customer/{email}       고객별 수령 내역
#   GET /pickup/store/{store_seq}      대리점별 수령 내역
#   GET /pickup/{p_id}                 수령 1건
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 수령 + 제품 정보를 함께 조회하는 공통 SELECT
# pick_up.SKU = product.SKU 로 수령한 제품 정보를 가져옴
# 여러 API가 같은 SELECT를 쓰므로 한 번만 작성하고 뒤에 WHERE/ORDER BY만 붙여서 사용
# pk / pro 는 테이블 별칭 (pick_up / product)
SELECT_SQL = """
    SELECT pk.p_id, pk.e_id, pk.email, pk.SKU, pk.store_seq, pk.p_date,
        pro.pr_name, pro.pr_brand, pro.size, pro.color
    FROM pick_up pk
    LEFT JOIN product pro
        ON pro.SKU = pk.SKU
"""


# DB 결과 한 줄을 응답 형식으로 변환 (번호는 SELECT_SQL 컬럼 순서)
# → SELECT_SQL의 컬럼을 추가하거나 순서를 바꾸면 여기 번호도 같이 수정해야 함
def to_dict(row):
    return {
        "p_id": row[0],        # 수령id
        "e_id": row[1],        # 확인한 직원
        "email": row[2],       # 고객
        "SKU": row[3],         # 제품 고유 코드
        "store_seq": row[4],   # 대리점
        "p_date": row[5],      # 수령일
        "pr_name": row[6],     # 제품명
        "pr_brand": row[7],    # 브랜드명
        "size": row[8],        # 사이즈
        "color": row[9],       # 색상
    }


# 전체 수령 내역 조회 (최신순)
@router.get("/")
def select_pickups():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY pk.p_date DESC"
            curs.execute(sql)
            rows = curs.fetchall()  # 결과 전체를 튜플 목록으로 받음
        return {"results": [to_dict(row) for row in rows]}  # 한 줄씩 dict로 변환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"수령 조회 실패: {e}")
    finally:
        conn.close()


# 고객별 수령 내역 조회 (최신순) 예: /pickup/customer/shin@test.com
@router.get("/customer/{email}")
def select_pickups_by_customer(email: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE pk.email = %s
                ORDER BY pk.p_date DESC
            """
            curs.execute(sql, (email,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"수령 조회 실패: {e}")
    finally:
        conn.close()


# 대리점별 수령 내역 조회 (최신순) → 대리점 화면에서 사용
@router.get("/store/{store_seq}")
def select_pickups_by_store(store_seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE pk.store_seq = %s
                ORDER BY pk.p_date DESC
            """
            curs.execute(sql, (store_seq,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"수령 조회 실패: {e}")
    finally:
        conn.close()


# 수령 1건 조회
# 주의: "/customer/...", "/store/..." 보다 아래에 있어야 주소가 p_id로 잘못 인식되지 않음
@router.get("/{p_id}")
def select_pickup(p_id: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE pk.p_id = %s"
            curs.execute(sql, (p_id,))
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
        if row is None:
            raise HTTPException(status_code=404, detail="수령 내역이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"수령 조회 실패: {e}")
    finally:
        conn.close()
