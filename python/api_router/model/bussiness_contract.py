# 계약서 조회 API → /model/bussiness_contract
# bussiness_contract 테이블: 모델 계약서 (기간, 금액, 상세내용)
from fastapi import APIRouter

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()

COLUMNS = "b_c_seq, b_c_start_date, b_c_end_date, b_c_price, b_c_detail"


def fmt(row):
    return {
        'b_c_seq': row[0],
        'b_c_start_date': row[1].strftime('%Y-%m-%d') if row[1] else None,
        'b_c_end_date': row[2].strftime('%Y-%m-%d') if row[2] else None,
        'b_c_price': row[3],
        'b_c_detail': row[4],
    }


# 계약서 목록: 최신 계약서부터 조회
@router.get("/list")
async def list_bussiness_contract():
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(f"SELECT {COLUMNS} FROM bussiness_contract ORDER BY b_c_seq DESC")
            rows = curs.fetchall()
        return {'results': [fmt(r) for r in rows]}
    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()


# 계약서 상세
@router.get("/detail")
async def detail_bussiness_contract(b_c_seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(f"SELECT {COLUMNS} FROM bussiness_contract WHERE b_c_seq = %s", (b_c_seq,))
            row = curs.fetchone()
        if row is None:
            return {'result': 'Error', 'message': 'bussiness_contract not found'}
        return fmt(row)
    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()
