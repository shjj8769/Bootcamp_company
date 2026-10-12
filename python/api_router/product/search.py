# python/APIRouter/product/search.py
# 제품 조회 API
#   GET /product/                  전체 제품
#   GET /product/model/{pr_code}   모델별 (같은 모델의 사이즈 전체)
#   GET /product/{SKU}             제품 1건
#   GET /product/{SKU}/image       제품 이미지
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
from fastapi import APIRouter, HTTPException, Response

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 제품 공통 SELECT (pr_image는 BLOB이라 목록에서 제외 → /{SKU}/image 로 따로 조회)
# 여러 API가 같은 SELECT를 쓰므로 한 번만 작성하고 뒤에 WHERE/ORDER BY만 붙여서 사용
SELECT_SQL = """
    SELECT SKU, pr_code, pr_name, pr_brand, pr_price,
        category, gender, size, color
    FROM product
"""


# DB 결과 한 줄을 응답 형식으로 변환 (번호는 SELECT_SQL 컬럼 순서)
# → SELECT_SQL의 컬럼을 추가하거나 순서를 바꾸면 여기 번호도 같이 수정해야 함
def to_dict(row):
    return {
        "SKU": row[0],       # 사이즈별 고유 코드
        "pr_code": row[1],   # 모델 코드
        "pr_name": row[2],   # 제품명
        "pr_brand": row[3],  # 브랜드명
        "pr_price": row[4],  # 제품가격
        "category": row[5],  # 품목
        "gender": row[6],    # 성별
        "size": row[7],      # 사이즈
        "color": row[8],     # 색상
    }


# 전체 제품 조회 (모델 코드 → 사이즈 순 정렬)
@router.get("/")
def select_products():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY pr_code, size"
            curs.execute(sql)
            rows = curs.fetchall()  # 결과 전체를 튜플 목록으로 받음
        return {"results": [to_dict(row) for row in rows]}  # 한 줄씩 dict로 변환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"제품 조회 실패: {e}")
    finally:
        conn.close()


# 모델별 조회 (같은 pr_code의 사이즈 전체) 예: /product/model/AD-JEN-W
# → 제품 상세 화면에서 선택 가능한 사이즈 목록을 보여줄 때 사용
@router.get("/model/{pr_code}")
def select_products_by_model(pr_code: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE pr_code = %s
                ORDER BY size
            """
            curs.execute(sql, (pr_code,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"제품 조회 실패: {e}")
    finally:
        conn.close()


# 제품 1건 조회 예: /product/AD-JEN-W-220-BLK
@router.get("/{SKU}")
def select_product(SKU: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE SKU = %s"
            curs.execute(sql, (SKU,))
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
        if row is None:
            raise HTTPException(status_code=404, detail="제품이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"제품 조회 실패: {e}")
    finally:
        conn.close()


# 제품 이미지 조회 (BLOB → 이미지로 바로 반환, Flutter에서 Image.network로 사용)
# 예: Image.network("http://서버주소:8000/product/AD-JEN-W-220-BLK/image")
@router.get("/{SKU}/image")
def select_product_image(SKU: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = "SELECT pr_image FROM product WHERE SKU = %s"
            curs.execute(sql, (SKU,))
            row = curs.fetchone()
        # 제품이 없거나(row None) 이미지가 비어 있으면(row[0] None) 404
        if row is None or row[0] is None:
            raise HTTPException(status_code=404, detail="제품 이미지가 없습니다")
        # JSON이 아닌 이미지 파일 그대로 응답 (jpeg 기준)
        return Response(content=row[0], media_type="image/jpeg")
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"제품 이미지 조회 실패: {e}")
    finally:
        conn.close()
