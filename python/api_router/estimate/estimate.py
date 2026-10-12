from fastapi import APIRouter
import pymysql

from db import connect

router = APIRouter()

# 부가세율 10%
VAT_RATE = 0.1

# 견적서 번호: 'MQ-' + 견적일(YYMMDD) + '-' + e_e_seq(3자리 0 패딩)
# 예: e_date=2026-09-23, e_e_seq=30 -> MQ-260923-030
# e_seq는 행 고유번호(PK), e_e_seq는 같은 견적서의 품목 행들이 공유하는 견적서 묶음 번호
# 견적서와 주문서(영수증)는 동일하게 취급한다. (추후 주문서 코드와 병합 예정)

# 견적서 목록: e_e_seq 기준 한 장당 한 줄, 최신 견적서부터 조회
@router.get("/list")
async def list_estimate():

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT e.e_e_seq,
                   CONCAT('MQ-', DATE_FORMAT(MIN(e.e_date), '%%y%%m%%d'), '-', LPAD(e.e_e_seq, 3, '0')) AS estimate_no,
                   e.m_id, m.m_name,
                   MIN(e.e_date) AS e_date,
                   SUM(e.e_price) AS supply_price
            FROM estimate e
            LEFT JOIN manufacture m ON m.m_id = e.m_id
            GROUP BY e.e_e_seq, e.m_id, m.m_name
            ORDER BY e.e_e_seq DESC
            """
        )
        rows = curs.fetchall()
        for row in rows:
            supply = int(row['supply_price'] or 0)
            row['vat'] = int(supply * VAT_RATE)
            row['total_price'] = supply + row['vat']
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()


# 견적서 상세: 같은 e_e_seq의 품목 행들을 e_seq 순서로 조회
@router.get("/detail")
async def detail_estimate(e_e_seq: int):

    conn = None

    try:
        conn = connect()
        curs = conn.cursor(pymysql.cursors.DictCursor)
        curs.execute(
            """
            SELECT e.e_seq, e.e_e_seq, e.pr_name, e.e_list_price, e.e_count,
                   e.e_price, e.e_date, e.m_id, e.e_id,
                   m.m_name, m.m_address
            FROM estimate e
            LEFT JOIN manufacture m ON m.m_id = e.m_id
            WHERE e.e_e_seq = %s
            ORDER BY e.e_seq
            """,
            (e_e_seq,),
        )
        rows = curs.fetchall()
        if not rows:
            return {'result': 'Error', 'message': 'estimate not found'}

        first = rows[0]
        # 순번은 DB 컬럼이 아니라 행 순서대로 계산
        for no, row in enumerate(rows, start=1):
            row['no'] = no

        supply = sum(int(r['e_price'] or 0) for r in rows)
        vat = int(supply * VAT_RATE)
        return {
            'estimate_no': 'MQ-{}-{:03d}'.format(first['e_date'].strftime('%y%m%d'), e_e_seq),
            'e_e_seq': e_e_seq,
            'e_date': first['e_date'],
            'm_id': first['m_id'],
            'm_name': first['m_name'],
            'm_address': first['m_address'],
            'items': rows,
            'supply_price': supply,
            'vat': vat,
            'total_price': supply + vat,
        }

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}

    finally:
        if conn is not None:
            conn.close()
