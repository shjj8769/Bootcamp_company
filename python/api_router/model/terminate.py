# 해지 API → /model/terminate
# terminate 테이블: 직원(e_id)이 모델(m_id)과의 계약을 해지한 내역 (c_seq는 해지 고유번호 AUTO_INCREMENT)
from datetime import datetime
from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()

SELECT_SQL = """
    SELECT t.c_seq, t.t_date, t.t_price, t.e_id, t.m_id, m.m_name
    FROM terminate t
    JOIN model m ON m.m_id = t.m_id
"""


def fmt(r):
    return {
        'c_seq': r[0],
        't_date': r[1].strftime('%Y-%m-%d') if r[1] else None,
        't_price': r[2],
        'e_id': r[3],
        'm_id': r[4],
        'm_name': r[5],
    }


# 해지 등록 요청 바디
class Terminate(BaseModel):
    e_id: str                          # 해지 처리한 직원 예: MKT-003
    m_id: int                          # 해지 대상 모델 (model.m_id)
    t_price: Optional[int] = None      # 해지 금액
    t_date: Optional[datetime] = None  # 비어 있으면 현재 시각으로 저장


# 해지 목록: 최신 해지부터 조회, m_id를 주면 해당 모델만 조회
@router.get("/list")
async def list_terminate(m_id: int = None):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL
            params = ()
            if m_id is not None:
                sql += " WHERE t.m_id = %s"
                params = (m_id,)
            curs.execute(sql + " ORDER BY t.c_seq DESC", params)
            rows = curs.fetchall()
        return {'results': [fmt(r) for r in rows]}
    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()


# 해지 상세
@router.get("/detail")
async def detail_terminate(c_seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(SELECT_SQL + " WHERE t.c_seq = %s", (c_seq,))
            row = curs.fetchone()
        if row is None:
            return {'result': 'Error', 'message': 'terminate not found'}
        return fmt(row)
    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()


# 해지 등록 (단순 insert, contact 테이블은 변경하지 않음)
@router.post("/")
async def insert_terminate(terminate: Terminate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                "INSERT INTO terminate (t_date, t_price, e_id, m_id) VALUES (%s, %s, %s, %s)",
                (terminate.t_date or datetime.now(), terminate.t_price, terminate.e_id, terminate.m_id),
            )
            c_seq = curs.lastrowid
        conn.commit()
        return {'result': 'OK', 'c_seq': c_seq}
    except Exception as e:
        conn.rollback()
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        conn.close()
