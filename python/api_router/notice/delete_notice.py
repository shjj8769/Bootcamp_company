from fastapi import APIRouter

from db import connect

router = APIRouter()

@router.delete("/{n_seq}")
async def delete(n_seq: int):
    conn = None

    try:
        conn = connect()
        curs = conn.cursor()
        curs.execute("DELETE FROM notice WHERE n_seq = %s", (n_seq,))

        # 삭제된 행이 없으면 존재하지 않는 공지
        if curs.rowcount == 0:
            conn.rollback()
            return {'result': 'Error', 'message': 'notice not found'}

        conn.commit()
        return {'result': 'OK'}
    except Exception as e:
        if conn is not None:
            conn.rollback()
        print("Error", e)
        return {'result': 'Error'}
    finally:
        if conn is not None:
            conn.close()
