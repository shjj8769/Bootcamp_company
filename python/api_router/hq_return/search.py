# python/APIRouter/hq_return/search.py
# 반납 조회 API
#   GET /hq_return/                     전체 반납 내역 (본사용)
#   GET /hq_return/store/{store_seq}    대리점별 반납 내역
#   GET /hq_return/{p_id}               반납 1건
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
# 제품 정보(제품명/사이즈/색상 등)는 SKU로 /product/{SKU} 에서 확인
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 반납 공통 SELECT (컬럼 순서는 DB 순서와 동일)
# return은 MySQL 예약어라 테이블 이름을 `return` 처럼 백틱으로 감싸야 함
# 여러 API가 같은 SELECT를 쓰므로 한 번만 작성하고 뒤에 WHERE/ORDER BY만 붙여서 사용
SELECT_SQL = """
    SELECT e_id, p_id, p_date, email, SKU, store_seq
    FROM `return`
"""


# DB 결과 한 줄을 응답 형식으로 변환 (번호는 SELECT_SQL 컬럼 순서)
# → SELECT_SQL의 컬럼을 추가하거나 순서를 바꾸면 여기 번호도 같이 수정해야 함
def to_dict(row):
    return {
        "e_id": row[0],        # 반납 처리 직원
        "p_id": row[1],        # 반납id
        "p_date": row[2],      # 반납일
        "email": row[3],       # 반품했던 고객
        "SKU": row[4],         # 제품 고유 코드
        "store_seq": row[5],   # 대리점
    }


# 전체 반납 내역 조회 (최신순)
@router.get("/")
def select_hq_returns():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY p_date DESC"
            curs.execute(sql)
            rows = curs.fetchall()  # 결과 전체를 튜플 목록으로 받음
        return {"results": [to_dict(row) for row in rows]}  # 한 줄씩 dict로 변환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반납 조회 실패: {e}")
    finally:
        conn.close()


# 대리점별 반납 내역 조회 (최신순)
@router.get("/store/{store_seq}")
def select_hq_returns_by_store(store_seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE store_seq = %s
                ORDER BY p_date DESC
            """
            curs.execute(sql, (store_seq,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반납 조회 실패: {e}")
    finally:
        conn.close()


# 반납 1건 조회
# 주의: "/store/..." 보다 아래에 있어야 "store"가 p_id로 잘못 인식되지 않음
@router.get("/{p_id}")
def select_hq_return(p_id: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE p_id = %s"
            curs.execute(sql, (p_id,))
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
        if row is None:
            raise HTTPException(status_code=404, detail="반납 내역이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반납 조회 실패: {e}")
    finally:
        conn.close()
