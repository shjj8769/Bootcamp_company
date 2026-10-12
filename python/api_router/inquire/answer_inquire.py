from fastapi import APIRouter, Form

from db import connect

router = APIRouter()

# 답변은 해당 문의 행(원글 또는 추가 문의)의 inquiry_detail, d_date, e_id에 저장
# i_state: 0 = 답변 대기, 1 = 답변 완료
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

        curs.execute("SELECT i_state FROM inquiry WHERE i_seq = %s", (i_seq,))
        origin = curs.fetchone()
        if origin is None:
            return {"result": "Error", "message": "inquiry not found"}
        if origin[0] == 1:
            return {"result": "Error", "message": "already answered"}

        curs.execute(
            """
            UPDATE inquiry
            SET inquiry_detail = %s, d_date = NOW(), e_id = %s, i_state = 1
            WHERE i_seq = %s
            """,
            (inquiry_detail.strip(), e_id, i_seq),
        )

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
