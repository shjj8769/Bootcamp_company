from fastapi import APIRouter
import pymysql

from db import connect

router = APIRouter()

# i_option 임시 매핑 (DB에 i_option 컬럼 추가 후 확정 필요)
INQUIRY_OPTION = {
    1: '상품 재입고 문의',
    2: '사이즈 교환 문의',
    3: '픽업 일정 문의',
    4: '반품 접수 문의',
}

# i_state: 0 = 답변 대기, 1 = 답변 완료
@router.get("")
async def list_inquire(i_state: int | None = None):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        # level 0 = 문의 원글, 최신 문의부터 조회 (i_state 지정 시 해당 상태만)
        sql = """
            SELECT q.i_seq, q.email, c.c_name, q.i_option, q.post, q.i_date, q.i_state,
                   a.inquiry_detail, a.i_date AS answer_date
            FROM inquiry q
            LEFT JOIN customer c ON c.email = q.email
            LEFT JOIN inquiry a ON a.i_comment_seq = q.i_seq AND a.level = 1
            WHERE q.level = 0
            """
        params = []
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
