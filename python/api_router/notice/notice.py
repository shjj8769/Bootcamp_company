from fastapi import APIRouter

from .delete_notice import router as delete_router
from .insert_notice import router as insert_router
from .list_notice import router as list_router
from .search_notice import router as search_router
from .update_notice import router as update_router

router = APIRouter()
router.include_router(delete_router, prefix='/delete')
router.include_router(insert_router, prefix='/insert')
router.include_router(list_router, prefix='/list')
router.include_router(search_router, prefix='/search')
router.include_router(update_router, prefix='/update')
