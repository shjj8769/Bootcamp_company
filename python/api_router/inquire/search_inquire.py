from fastapi import APIRouter, Form
import pymysql

from db import connect
from .list_inquire import SELECT_INQUIRY, attach_follow_ups

router = APIRouter()

# 문의번호(i_seq), 문의 내용(post), 고객 이름(c_name) 중 하나라도 일치하면 조회
@router.post("")
async def search_inquire(
    keyword: str = Form(...),
    i_state: int | None = Form(None),
):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        like = '%' + keyword.strip() + '%'
        sql = SELECT_INQUIRY + """
              AND (CAST(q.i_seq AS CHAR) LIKE %s OR q.post LIKE %s OR c.c_name LIKE %s)
            """
        params = [like, like, like]
        if i_state is not None:
            sql += " AND q.i_state = %s"
            params.append(i_state)
        sql += " ORDER BY q.i_seq DESC"

        curs.execute(sql, params)
        rows = attach_follow_ups(curs, curs.fetchall())
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
