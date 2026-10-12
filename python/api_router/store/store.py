from fastapi import APIRouter

from .list_store import router as list_router

router = APIRouter()
router.include_router(list_router, prefix='/list')
