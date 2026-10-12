from fastapi import APIRouter, Form
import pymysql

from db import connect
from .auth_employee import is_store_team, make_token, verify_password

router = APIRouter()


# 공통 로그인 처리: 부서(e_team)가 대리점이면 store 로그인만, 그 외는 hq 로그인만 허용
# 아이디 없음/비밀번호 불일치/로그인 종류 불일치는 구분하지 않고 같은 메시지를 반환
def login(e_id: str, password: str, kind: str):
    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT e_id, e_jobtitle, e_team, employee_password, store_seq
            FROM employee
            WHERE e_id = %s
            """,
            (e_id.strip(),),
        )
        row = curs.fetchone()

        fail = {"result": "Error", "message": "invalid id or password"}
        if row is None or not verify_password(password, row['employee_password']):
            return fail
        if is_store_team(row['e_team']) != (kind == 'store'):
            return fail
        # 대리점 직원은 소속 대리점(store_seq)이 있어야 로그인 가능
        if kind == 'store' and row['store_seq'] is None:
            return fail

        employee = {
            'e_id': row['e_id'],
            'e_jobtitle': row['e_jobtitle'],
            'e_team': row['e_team'],
            'store_seq': row['store_seq'],
        }
        token = make_token({**employee, 'kind': kind})
        return {"result": "OK", "token": token, "kind": kind, "employee": employee}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()


# 본사 직원 로그인
@router.post("/hq")
async def login_hq(
    e_id: str = Form(...),
    password: str = Form(...),
):
    return login(e_id, password, 'hq')


# 대리점 직원 로그인
@router.post("/store")
async def login_store(
    e_id: str = Form(...),
    password: str = Form(...),
):
    return login(e_id, password, 'store')
