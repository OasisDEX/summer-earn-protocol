import { Product } from '../models/Product'

export class Protocol {
  name: string
  products: Product[]

  constructor(name: string, products: Product[]) {
    this.name = name
    this.products = products
  }
}
