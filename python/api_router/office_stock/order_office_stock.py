from fastapi import APIRouter, Depends
import pymysql

from api_router.employee.auth_employee import get_db, require_hq
from api_router.qr import qr_memory
from db import connect
from .stock_common import OFFICE, SEND

router = APIRouter()

# 주문 상태: 발송 전 -> 발송중(send 생성, 대리점 입고 전) -> 발송완료(대리점 입고 확인) -> 픽업완료(고객 QR 픽업)
STATUS_WAIT = '발송 전'
STATUS_SENDING = '발송중'
STATUS_SENT = '발송완료'
STATUS_PICKED = '픽업완료'


# 고객 결제로 쌓인 주문(MySQL purchase) 전체와 진행 상태를 조회 (본사 직원 전용, 최신순)
# 상태는 send 문서(p_id로 연결)의 s_check(입고 확인)와 s_picked(픽업 완료)로 판단
@router.get("")
async def order_office_stock(employee: dict = Depends(require_hq)):

    conn = None

    try:
        db = get_db()
        sends = {}
        for d in db.collection(SEND).stream():
            if d.id == '_erd':
                continue
            data = d.to_dict()
            sends[data.get('p_id')] = {**data, 'send_id': d.id}

        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT p.p_id, p.store_seq, s.name AS s_name, p.SKU AS pr_id, p.p_count, p.p_date
            FROM purchase p
            LEFT JOIN store s ON s.seq = p.store_seq
            ORDER BY p.p_id DESC
            """
        )
        rows = curs.fetchall()

        for row in rows:
            send = sends.get(row['p_id'])
            if send is None:
                row['status'] = STATUS_PICKED if qr_memory.is_picked(row['p_id']) else STATUS_WAIT
            elif send.get('s_picked'):
                row['status'] = STATUS_PICKED
            elif send.get('s_check') == 1:
                row['status'] = STATUS_SENT
            else:
                row['status'] = STATUS_SENDING
            row['send_id'] = send['send_id'] if send else None
            row['s_date'] = send.get('s_date') if send else None

            # 발송 전 주문만 현재 본사 재고를 확인해 발송 가능 여부를 알려줌
            row['now_count'] = None
            row['can_send'] = False
            if row['status'] == STATUS_WAIT:
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
