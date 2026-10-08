from fastapi import APIRouter, Form
import pymysql

from db import connect

router = APIRouter()

@router.post("")
async def search(
    n_title: str = Form(...)):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT n_seq, n_classification, n_title, n_detail, n_date
            FROM notice
            WHERE n_title LIKE %s
            """,
            ('%' + n_title + '%',)
        )
        rows = curs.fetchall()
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
