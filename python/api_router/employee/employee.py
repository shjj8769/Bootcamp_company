from fastapi import APIRouter

from .approver_employee import router as approver_router
from .login_employee import router as login_router
from .me_employee import router as me_router

router = APIRouter()
router.include_router(approver_router, prefix='/approver')
router.include_router(login_router, prefix='/login')
router.include_router(me_router, prefix='/me')
