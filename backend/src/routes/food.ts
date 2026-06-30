import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { requireAuth } from "./middleware/auth.js";
import {
  lookupBarcode,
  searchProducts,
  type FoodProduct,
} from "../food/openFoodFacts.js";
import { parseLangCode } from "../lib/lang.js";

// FoodProduct → snake_case ответ API
function serialize(p: FoodProduct) {
  return {
    code: p.code,
    name: p.name,
    brand: p.brand,
    image: p.image,
    per_100g: {
      calories: p.per100g.calories,
      protein: p.per100g.protein,
      fat: p.per100g.fat,
      carbs: p.per100g.carbs,
      sugar: p.per100g.sugar,
      fiber: p.per100g.fiber,
    },
  };
}

const searchQuerySchema = z.object({ q: z.string().min(1) });

const foodRoutes: FastifyPluginAsync = async (fastify) => {
  // FOOD-01: поиск продукта по штрихкоду (данные из Open Food Facts)
  fastify.get(
    "/api/v1/food/barcode/:code",
    { preHandler: requireAuth },
    async (request, reply) => {
      const { code } = request.params as { code: string };
      if (!/^\d{6,14}$/.test(code)) {
        return reply.status(400).send({ error: "Invalid barcode" });
      }
      const lang = parseLangCode(request.headers["accept-language"]);
      try {
        const product = await lookupBarcode(code, lang);
        if (!product) return reply.status(404).send({ error: "Not found" });
        return reply.status(200).send(serialize(product));
      } catch (err) {
        fastify.log.error({ err }, "OFF barcode lookup failed");
        return reply
          .status(502)
          .send({ error: "Food database unavailable. Try again later." });
      }
    }
  );

  // FOOD-02: текстовый поиск продуктов
  fastify.get(
    "/api/v1/food/search",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = searchQuerySchema.safeParse(request.query);
      if (!parsed.success) {
        return reply.status(400).send({ error: "Query 'q' is required" });
      }
      const lang = parseLangCode(request.headers["accept-language"]);
      try {
        const products = await searchProducts(parsed.data.q, 20, lang);
        return reply.status(200).send({ products: products.map(serialize) });
      } catch (err) {
        fastify.log.error({ err }, "OFF search failed");
        return reply
          .status(502)
          .send({ error: "Food database unavailable. Try again later." });
      }
    }
  );
};

export default foodRoutes;
