from fastapi import APIRouter, Form
import pymysql

from db import connect
from .list_inquire import INQUIRY_OPTION

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
        sql = """
            SELECT q.i_seq, q.email, c.c_name, q.i_option, q.post, q.i_date, q.i_state,
                   a.inquiry_detail, a.i_date AS answer_date
            FROM inquiry q
            LEFT JOIN customer c ON c.email = q.email
            LEFT JOIN inquiry a ON a.i_comment_seq = q.i_seq AND a.level = 1
            WHERE q.level = 0
              AND (CAST(q.i_seq AS CHAR) LIKE %s OR q.post LIKE %s OR c.c_name LIKE %s)
            """
        params = [like, like, like]
        if i_state is not None:
            sql += " AND q.i_state = %s"
            params.append(i_state)
        sql += " ORDER BY q.i_seq DESC"

        curs.execute(sql, params)
        rows = curs.fetchall()
        for row in rows:
            row['title'] = INQUIRY_OPTION.get(row['i_option'], '기타 문의')
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
