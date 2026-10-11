from fastapi import APIRouter, Form

from db import connect

router = APIRouter()

# 답변은 level 1 행으로 저장하고, i_comment_seq에 원글 i_seq를 기록
@router.post("")
async def answer_inquire(
    i_seq: int = Form(...),
    e_id: str = Form(...),
    inquiry_detail: str = Form(...),
):
    conn = None

    try:
        conn = connect()
        curs = conn.cursor()

        # 원글 확인 및 이메일 조회
        curs.execute(
            "SELECT email, i_state FROM inquiry WHERE i_seq = %s AND level = 0",
            (i_seq,),
        )
        origin = curs.fetchone()
        if origin is None:
            return {"result": "Error", "message": "inquiry not found"}
        if origin[1] == 1:
            return {"result": "Error", "message": "already answered"}

        curs.execute(
            """
            INSERT INTO inquiry (email, e_id, inquiry_detail, i_date, i_state, i_comment_seq, level)
            VALUES (%s, %s, %s, NOW(), 1, %s, 1)
            """,
            (origin[0], e_id, inquiry_detail.strip(), i_seq),
        )
        # 원글 처리상태를 답변 완료로 변경
        curs.execute("UPDATE inquiry SET i_state = 1 WHERE i_seq = %s", (i_seq,))

        conn.commit()
        return {"result": "OK", "i_seq": i_seq}
    except Exception as e:
        if conn is not None:
            conn.rollback()
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        if conn is not None:
            conn.close()
