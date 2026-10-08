from fastapi import APIRouter
import pymysql

from db import connect

router = APIRouter()

@router.get("")
async def list_notice():

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        # n_seq 기준 최신 공지부터 전체 조회
        curs.execute(
            """
            SELECT n_seq, n_classification, n_title, n_detail, n_date
            FROM notice
            ORDER BY n_seq DESC
            """
        )
        rows = curs.fetchall()
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
