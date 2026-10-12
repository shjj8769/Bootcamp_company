from fastapi import APIRouter

from .list_store_stock import router as list_router
from .receive_store_stock import router as receive_router

router = APIRouter()
router.include_router(list_router, prefix='/list')
router.include_router(receive_router, prefix='/receive')
