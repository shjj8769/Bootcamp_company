# 계약 조회 API → /model/contact
# contact 테이블: 직원(e_id)이 모델(m_id)과 계약서(b_c_seq)로 계약한 내역
from fastapi import APIRouter

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()

# 모델 이름과 계약서 정보를 함께 조회
SELECT_SQL = """
    SELECT c.c_date, c.e_id, c.m_id, m.m_name, c.b_c_seq,
           b.b_c_start_date, b.b_c_end_date, b.b_c_price
    FROM contact c
    JOIN model m ON m.m_id = c.m_id
    JOIN bussiness_contract b ON b.b_c_seq = c.b_c_seq
"""


def date_str(value):
    return value.strftime('%Y-%m-%d') if value else None


def fmt(r):
    return {
        'c_date': date_str(r[0]),
        'e_id': r[1],
        'm_id': r[2],
        'm_name': r[3],
        'b_c_seq': r[4],
        'b_c_start_date': date_str(r[5]),
        'b_c_end_date': date_str(r[6]),
        'b_c_price': r[7],
    }


# 계약 목록: 최신 계약일부터 조회, m_id를 주면 해당 모델만 조회
@router.get("/list")
async def list_contact(m_id: int = None):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL
            params = ()
            if m_id is not None:
                sql += " WHERE c.m_id = %s"
                params = (m_id,)
            curs.execute(sql + " ORDER BY c.c_date DESC", params)
            rows = curs.fetchall()
        return {'results': [fmt(r) for r in rows]}
    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()


# 계약 상세: PK(e_id, m_id, b_c_seq)로 1건 조회
@router.get("/detail")
async def detail_contact(e_id: str, m_id: int, b_c_seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                SELECT_SQL + " WHERE c.e_id = %s AND c.m_id = %s AND c.b_c_seq = %s",
                (e_id, m_id, b_c_seq),
            )
            row = curs.fetchone()
        if row is None:
            return {'result': 'Error', 'message': 'contact not found'}
        return fmt(row)
    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()
