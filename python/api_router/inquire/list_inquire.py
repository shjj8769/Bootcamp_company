from fastapi import APIRouter
import pymysql

from db import connect

router = APIRouter()

# i_option 매핑 (i_option이 NULL이면 문의 내용 앞부분을 제목으로 사용)
INQUIRY_OPTION = {
    1: '상품 재입고 문의',
    2: '사이즈 교환 문의',
    3: '픽업 일정 문의',
    4: '반품 접수 문의',
}

# 원글 조회 SQL (level 0). 한 행에 문의(post)와 답변(inquiry_detail, d_date)이 함께 저장됨
SELECT_INQUIRY = """
    SELECT q.i_seq, q.email, c.c_name, q.i_option, q.post, q.i_date,
           q.inquiry_detail, q.d_date, q.i_state, q.e_id
    FROM inquiry q
    LEFT JOIN customer c ON c.email = q.email
    WHERE q.level = 0
    """


def make_title(row):
    return INQUIRY_OPTION.get(row['i_option']) or (row['post'] or '')[:30]


# 원글에 추가 문의(level 1, i_comment_seq = 원글 i_seq)를 follow_ups로 붙임
def attach_follow_ups(curs, rows):
    for row in rows:
        row['title'] = make_title(row)
        row['follow_ups'] = []
    if not rows:
        return rows

    by_seq = {row['i_seq']: row for row in rows}
    curs.execute(
        """
        SELECT i_seq, i_comment_seq, level, post, i_date, inquiry_detail, d_date, i_state, e_id
        FROM inquiry
        WHERE level = 1 AND i_comment_seq IN %s
        ORDER BY i_seq
        """,
        (tuple(by_seq),),
    )
    for child in curs.fetchall():
        by_seq[child['i_comment_seq']]['follow_ups'].append(child)
    return rows


# i_state: 0 = 답변 대기, 1 = 답변 완료
@router.get("")
async def list_inquire(i_state: int | None = None):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        # 최신 문의부터 조회 (i_state 지정 시 원글 상태가 일치하는 것만)
        sql = SELECT_INQUIRY
        params = []
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
