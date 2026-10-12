from fastapi import APIRouter

from .list_office_stock import router as list_router
from .order_office_stock import router as order_router
from .receive_office_stock import router as receive_router
from .send_office_stock import router as send_router

router = APIRouter()
router.include_router(list_router, prefix='/list')
router.include_router(order_router, prefix='/order')
router.include_router(receive_router, prefix='/receive')
router.include_router(send_router, prefix='/send')
