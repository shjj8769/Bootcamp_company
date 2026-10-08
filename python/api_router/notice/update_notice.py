from fastapi import APIRouter, Form

from db import connect

router = APIRouter()

@router.post("")
async def update_notice(
    n_seq: int = Form(...),
    n_classification: str = Form(...),
    n_title: str = Form(...),
    n_detail: str = Form(...),
):
    conn = None

    try:
        conn = connect(found_rows=True)
        curs = conn.cursor()

        curs.execute(
            """
            UPDATE notice
            SET n_classification = %s, n_title = %s, n_detail = %s
            WHERE n_seq = %s
            """,
            (
                n_classification.strip(),
                n_title.strip(),
                n_detail.strip(),
                n_seq,
            ),
        )

        # 대상 공지가 없으면 에러 반환
        if curs.rowcount == 0:
            conn.rollback()
            return {"result": "Error", "message": "notice not found"}

        conn.commit()
        return {"result": "OK", "n_seq": n_seq}
    except Exception as e:
        if conn is not None:
            conn.rollback()
        print("Error:", e)
        return {'result': 'Error'}
    finally:
        if conn is not None:
            conn.close()