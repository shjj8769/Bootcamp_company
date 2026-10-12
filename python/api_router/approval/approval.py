from fastapi import APIRouter

from .list_approval import router as list_router
from .order_approval import router as order_router
from .sign_approval import router as sign_router
from .submit_approval import router as submit_router

router = APIRouter()
router.include_router(list_router, prefix='/list')
router.include_router(order_router, prefix='/order')
router.include_router(sign_router, prefix='/sign')
router.include_router(submit_router, prefix='/submit')
