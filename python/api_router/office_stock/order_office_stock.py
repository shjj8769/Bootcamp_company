from fastapi import APIRouter, Depends
import pymysql

from api_router.employee.auth_employee import get_db, require_hq
from db import connect
from .stock_common import OFFICE, SEND

router = APIRouter()


# 고객 결제로 쌓인 주문(MySQL purchase) 중 아직 발송하지 않은 것을 조회 (본사 직원 전용)
# 발송 완료 여부는 send 문서의 p_id로 판단
@router.get("")
async def order_office_stock(employee: dict = Depends(require_hq)):

    conn = None

    try:
        db = get_db()
        sent = {d.to_dict().get('p_id') for d in db.collection(SEND).stream() if d.id != '_erd'}

        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT p.p_id, p.store_seq, s.name AS s_name, p.SKU AS pr_id, p.p_count, p.p_date
            FROM purchase p
            LEFT JOIN store s ON s.seq = p.store_seq
            ORDER BY p.p_id
            """
        )
        rows = [r for r in curs.fetchall() if r['p_id'] not in sent]

        # 현재 본사 재고를 함께 보여줘서 발송 가능 여부를 판단
        for row in rows:
            snap = db.collection(OFFICE).document(row['pr_id']).get()
            row['now_count'] = (snap.to_dict() or {}).get('now_count', 0) if snap.exists else 0
            row['can_send'] = row['now_count'] >= (row['p_count'] or 0)
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
