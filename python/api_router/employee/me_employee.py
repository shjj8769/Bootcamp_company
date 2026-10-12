from fastapi import APIRouter, Depends
import pymysql

from db import connect
from .auth_employee import get_current_employee, get_employee

router = APIRouter()


# 로그인한 직원 본인 정보 조회 (직원 정보는 Firestore, 대리점 이름은 MySQL store 테이블)
@router.get("")
async def me_employee(employee: dict = Depends(get_current_employee)):

    conn = None

    try:
        row = get_employee(employee['e_id'])
        if row is None:
            return {"result": "Error", "message": "employee not found"}

        result = {
            'e_id': row['e_id'],
            'e_jobtitle': row.get('e_jobtitle'),
            'e_team': row.get('e_team'),
            'store_seq': row.get('store_seq'),
            'store_name': None,
            'kind': employee['kind'],
        }
        # 대리점 직원이면 소속 대리점 이름 조회
        if result['store_seq']:
            conn = connect()
            curs = conn.cursor(pymysql.cursors.DictCursor)
            curs.execute("SELECT name FROM store WHERE seq = %s", (result['store_seq'],))
            store = curs.fetchone()
            result['store_name'] = store['name'] if store else None
        return {'result': result}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
