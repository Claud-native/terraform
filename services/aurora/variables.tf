# ========================================
# VARIABLES - AURORA MODULE
# ========================================

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora"
  type        = list(string)
}

variable "api_security_group_id" {
  description = "Security group ID of the API ECS tasks"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "educloud"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "rsa_private_key" {
  description = "RSA private key for password decryption"
  type        = string
  sensitive   = true
  default     = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCl6AzgD187rXe4\nOLwvdnryTVZfGsM4PCDpv2bhlau314m3lFA+UenJhmNRYpB5NJrxZgV5UgyIx5dc\nRr594PGyUETYHJSPEJ+NnK9Z8SJ+GxeFX9mAGdyxTxcZPRucr6diwm+h21Fu0uJy\nvbxkazLrWCeWastqF7W64qU+9hVw6JhkRwH2J9LtlP/LCk/3pds2Zv0tjeVCoTyK\ndwEILzc8yW3FBNqt87gHzE9iIanpSLeRKuge2cy4zxqP3wg9Zgk6+v9jOLTisniG\nckP3Z7kwlZU7zbkHjfkqdB3MB51C6UpBx8mKFGXMLh84KbUBL8/iRFtXO2jqIbvh\n0XusQwjnAgMBAAECggEADMM0llnoYA1gm83VgCszmwcjAU7sPJu3hnPAZNMgMhTF\nFde1co3Xl7acVkroRUKsNqy7+BC9QRplhOY2SjWvMiHloeBU90p2k6y9eoRHvH62\nCP8OGsIijYtBgiIGyT9j939wmflmoslbPStmXi027g7KgNI3UrJ/OuCriJPio1xJ\neT+ML68kPsbQlJ3YolSBku3GARaQnAGpQba5B/XZlO35OEEjTSSHO9yAf+JBrpHX\nmzdzJAzQeD5HCOyiStbGjhQEMoVUcRTxYRs9vqxBcWtxmPzJMuTFuzKopPeP/Gng\nr5+Dh4+3e1Mgq+tkMrWwFM0TlnqY4Wxpqlfl7O15yQKBgQDY0ZZT29lt0mxNaUA6\nlS4Gq1e2ipgKd1PEos8B+/bzjHY+1UEWxXsOHTvDFF1fGKDHGxggP6DXcI8CNGmA\nVBh3GmY2Iozrn3UpDf8VGeGVI7OqBCdbSRbjK6572n1vQLzSqSChVlvGBbiNs0Db\nX+XLFaIynDpgRiuglbNzBEE3qQKBgQDD4yxNw5xRdX2uk7vaUfu7fL90mSGXIMzI\nPi8UhIuqgEkfIgRtzIBC6uh6aP8XKB7uC9eBCTF3oLgsGZC8uO7ZTQJALI+1IinD\nPjnplRagEWhUJ5wZdpBxhmg1RWPYJKjEmhcKMCd4svRp1VbumLAenuy7p8ZkRPCX\nt5Y9BI5WDwKBgHh3ctvjEhqnyI72RL6H9ou0FccRmEpwZHWjs/q5QUuupmBg4opB\nbQ65hWPtY7ebmnEmB7CbScWJ/5tM/bVUhEdgvpujdMLR1SnbYfgaajEQJhn3ttpM\ncNAFjCu6iOkQghlV6RBbSCBtO05X41hAHxBIU9dk4DZvpnvR0WO9YHMJAoGBALBY\neA791WEEC4Q5XTka6yuLD3SxUqsSDSkLyiiHdpCk8q8DWcda/fDAN0/T7Cl1pfqZ\nUIXKt+zBFGwnC8TKG8QmbqtFMo5XVg99mnctD3REl46DJiVKNpjs7i1e7Zas0f5D\n1hAG79HaEOyh8aPUc2Dto6MAVDr6UTnUPX1q95SDAoGACb5GsNbTrRhWcaRF5w+w\nOCzlbfv6VIFHQClHZqv+WpzBJe52PlTT0PoAKbqDbtdMkFZ9WBIhvWzQ9nrWiiVV\nl4lSkAtiSDO8I5AHe6jd0eOl1a67z8c5YegEJWnKZ+OFJ59e2TaiKsPXrU1/Wbjt\n5Cva3rCRmOddrJx15SWwtp8=\n-----END PRIVATE KEY-----"
}
