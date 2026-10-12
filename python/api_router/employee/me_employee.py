from fastapi import APIRouter, Depends
import pymysql

from db import connect
from .auth_employee import get_current_employee

router = APIRouter()


# 로그인한 직원 본인 정보 조회 (대리점 직원이면 소속 대리점 이름 포함)
@router.get("")
async def me_employee(employee: dict = Depends(get_current_employee)):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT e.e_id, e.e_jobtitle, e.e_team, e.store_seq, s.name AS store_name
            FROM employee e
            LEFT JOIN store s ON s.seq = e.store_seq
            WHERE e.e_id = %s
            """,
            (employee['e_id'],),
        )
        row = curs.fetchone()
        if row is None:
            return {"result": "Error", "message": "employee not found"}
        row['kind'] = employee['kind']
        return {'result': row}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
