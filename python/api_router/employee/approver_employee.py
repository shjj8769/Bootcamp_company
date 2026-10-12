from fastapi import APIRouter, Depends
import pymysql

from db import connect
from .auth_employee import approval_line, require_hq

router = APIRouter()


# 로그인한 본사 직원의 결재 라인 조회: 같은 부서에서 사원 -> 팀장 -> 임원 순서
@router.get("")
async def approver_employee(employee: dict = Depends(require_hq)):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        return {'results': approval_line(curs, employee)}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
