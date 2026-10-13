from fastapi import APIRouter

from api_router.model.bussiness_contract import router as bussiness_contract_router
from api_router.model.contact import router as contact_router
from api_router.model.terminate import router as terminate_router

router = APIRouter()

router.include_router(contact_router, prefix='/contact', tags=['model contact'])
router.include_router(terminate_router, prefix='/terminate', tags=['model terminate'])
router.include_router(bussiness_contract_router, prefix='/bussiness_contract', tags=['model bussiness_contract'])
