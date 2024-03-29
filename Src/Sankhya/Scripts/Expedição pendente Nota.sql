SELECT F1.NUNOTA 
FROM sankhya.AD_PEDIDOVTEXSCFLUXO AS F1  WITH (NOLOCK)
WHERE F1.OCORRENCIA = 'E'
AND NOT EXISTS (
	SELECT 1
	FROM sankhya.AD_PEDIDOVTEXSCFLUXO AS F2 WITH (NOLOCK)
	WHERE F2.NUNOTA = F1.NUNOTA
	AND F2.OCORRENCIA IN ('C','R')
) AND NOT EXISTS (
	SELECT 1
    FROM sankhya.AD_PEDIDOVTEXSCFLUXO AS F3 WITH (NOLOCK)
    WHERE F3.PEDORIGINAL = F1.PEDORIGINAL
    AND F3.OCORRENCIA = 'V'
) AND EXISTS (
	SELECT 1
    FROM sankhya.TGFCAB AS C WITH (NOLOCK)
    WHERE C.NUNOTA = F1.NUNOTA
    AND C.PENDENTE = 'N'
)