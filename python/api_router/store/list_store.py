from fastapi import APIRouter, Depends
import pymysql

from api_router.employee.auth_employee import require_hq
from db import connect

router = APIRouter()


# 대리점 위치 목록 (본사 직원 전용): 지도 마커와 매장 정보 표시용
@router.get("")
async def list_store(employee: dict = Depends(require_hq)):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT seq AS store_seq, name, address, dealer_number AS phone, lat, lng
            FROM store
            ORDER BY seq
            """
        )
        return {'results': curs.fetchall()}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
