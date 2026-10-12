from fastapi import APIRouter, Depends

from api_router.employee.auth_employee import get_db, require_hq
from .stock_common import BASE_COUNT, LEAST_COUNT, OFFICE, need_order

router = APIRouter()


# 본사재고 목록 (본사 직원 전용). need_order=true면 최소수량(30%) 미만이라 발주 요청 필요
@router.get("")
async def list_office_stock(employee: dict = Depends(require_hq)):

    try:
        rows = []
        for doc in get_db().collection(OFFICE).stream():
            if doc.id == '_erd':
                continue
            row = doc.to_dict()
            row['pr_id'] = doc.id
            row['least_count'] = LEAST_COUNT
            row['base_count'] = BASE_COUNT
            row['need_order'] = need_order(row.get('now_count'))
            rows.append(row)
        rows.sort(key=lambda r: r['pr_id'])
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
