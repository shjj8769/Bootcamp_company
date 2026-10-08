from datetime import datetime
from fastapi import APIRouter, Form

from db import connect

router = APIRouter()

@router.post("")
async def insert_notice(
    n_classification: str = Form(...),
    n_title: str = Form(...),
    n_detail: str = Form(...),
    e_id: int = Form(...),
):
    conn = None
    curs = None

    try:
        # 분류, 제목, 내용이 비어 있는 공지는 미리 차단
        if (
            not n_classification.strip()
            or not n_title.strip()
            or not n_detail.strip()
        ):
            return {
                "result": "Error",
                "message": "n_classification, n_title, n_detail are required",
            }

        conn = connect()
        curs = conn.cursor()

        # n_seq는 AUTO_INCREMENT이므로 INSERT에서 제외하고, 등록일자는 서버 현재 시각으로 저장
        insert_notice_sql = """
            INSERT INTO notice (e_id, n_classification, n_title, n_detail, n_date)
            VALUES (%s, %s, %s, %s, %s)
        """
        created_date = datetime.now()
        curs.execute(
            insert_notice_sql,
            (
                e_id,
                n_classification.strip(),
                n_title.strip(),
                n_detail.strip(),
                created_date,
            ),
        )
        n_seq = curs.lastrowid

        conn.commit()
        return {
            "result": "OK",
            "n_seq": n_seq,
            "n_date": created_date.isoformat(sep=" ", timespec="seconds"),
        }

    except Exception as e:
        # DB 오류가 발생하면 Rollback
        if conn is not None:
            conn.rollback()
        print("Error:", e)
        return {"result": "Error"}

    finally:
        if curs is not None:
            curs.close()
        if conn is not None:
            conn.close()
