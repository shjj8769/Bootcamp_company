from fastapi import APIRouter

from .answer_inquire import router as answer_router
from .list_inquire import router as list_router
from .search_inquire import router as search_router

router = APIRouter()
router.include_router(answer_router, prefix='/answer')
router.include_router(list_router, prefix='/list')
router.include_router(search_router, prefix='/search')
