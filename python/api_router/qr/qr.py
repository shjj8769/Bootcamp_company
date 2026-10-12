from fastapi import APIRouter

from .active_qr import router as active_router
from .issue_qr import router as issue_router
from .scan_qr import router as scan_router

router = APIRouter()
router.include_router(active_router, prefix='/active')
router.include_router(issue_router, prefix='/issue')
router.include_router(scan_router, prefix='/scan')
