from fastapi import APIRouter, Response
import pymysql

from db import connect

router = APIRouter()

@router.get("/list")
async def list_review():

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        # r_seq 기준 최신 리뷰부터 전체 조회 (본사 데이터 분석용)
        # image는 LONGBLOB이라 목록에서는 제외하고, 이미지 유무만 내려줌
        curs.execute(
            """
            SELECT r.r_seq, r.r_date, r.post, r.rating, r.fit, r.`like count` AS likecount,
                (r.image IS NOT NULL) AS has_image,
                c.c_name, p.pr_name
            FROM review r
            LEFT JOIN customer c ON r.email = c.email
            LEFT JOIN product p ON r.sku = p.sku
            ORDER BY r.r_seq DESC
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


@router.get("/detail/{r_seq}")
async def get_review_detail(r_seq: int):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT r.r_seq, r.r_date, r.post, r.rating, r.fit, r.`like count` AS likecount,
                   (r.image IS NOT NULL) AS has_image,
                   c.c_name, p.pr_name
            FROM review r
            LEFT JOIN customer c ON r.email = c.email
            LEFT JOIN product p ON r.sku = p.sku
            WHERE r.r_seq = %s
            """,
            (r_seq,)
        )
        row = curs.fetchone()
        if row is None:
            return {'result': 'NotFound'}
        return {'result': row}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()


@router.get("/image/{r_seq}")
async def get_review_image(r_seq: int):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor()
        curs.execute("SELECT image FROM review WHERE r_seq = %s", (r_seq,))
        row = curs.fetchone()
        if row is None or row[0] is None:
            return Response(status_code=404)
        return Response(content=row[0], media_type="image/jpeg")

    except Exception as e:
        print("Error:", e)
        return Response(status_code=500)

    finally:
        if conn is not None:
            conn.close()
