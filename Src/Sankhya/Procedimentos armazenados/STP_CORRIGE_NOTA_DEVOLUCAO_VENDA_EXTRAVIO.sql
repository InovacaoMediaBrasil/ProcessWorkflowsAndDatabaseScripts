USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_NOTA_DEVOLUCAO_VENDA_EXTRAVIO]    Script Date: 10/10/2017 11:16:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Rafael Turra
-- Create date: 2016-12-05
-- Description:	Corrige os valores de imposto e total da nota para aprovação da nota de devoluçaõ de venda
-- =============================================
ALTER PROCEDURE [sankhya].[STP_CORRIGE_NOTA_DEVOLUCAO_VENDA_EXTRAVIO]
       @P_NUNOTA INT, 
	   @P_SUCESSO VARCHAR OUTPUT, 
	   @P_MENSAGEM VARCHAR OUTPUT, 
	   @P_CODUSULIB NUMERIC OUTPUT
AS
BEGIN   	   	
		/* Passos para corrigir a nota de devolução de venda: */
		/* 1. colocar o valor dos produtos kits igual a somatória do itens; */
		UPDATE	ITE SET	VLRUNIT = sankhya.VALOR_DO_KIT_MAIS_BRINDES(ITE.NUNOTA,SEQUENCIA),
						VLRTOT = sankhya.VALOR_DO_KIT_MAIS_BRINDES(ITE.NUNOTA,SEQUENCIA)*QTDNEG,
						VLRDESC = sankhya.VALOR_DO_DESCONTO_DO_KIT_MAIS_BRINDES(ITE.NUNOTA,SEQUENCIA)
		FROM	sankhya.TGFITE ITE
				INNER JOIN sankhya.TGFCAB CAB ON CAB.NUNOTA = ITE.NUNOTA
		WHERE	ITE.USOPROD = 'R'
				AND CODVOL = 'KT'
				AND ITE.NUNOTA = @P_NUNOTA;
		
		/* 2. retirar o frete* e alterar o VLRNOTA sendo a somatória dos itens; */
		UPDATE	sankhya.TGFCAB
		SET		VLRNOTA = sankhya.FN_PRECO_DOS_ITENS_DO_PEDIDO(NUNOTA),
				VLRFRETE = 0
		WHERE	NUNOTA = @P_NUNOTA;

		/* 3. alterar o valor na DIN para ficar igual ao valor da ITE; */
		/* resolvendo cofins */
		UPDATE	DIN
		SET		BASE = (VLRTOT-VLRDESC),
				BASERED = (VLRTOT-VLRDESC),
				ALIQUOTA = 3,
				VALOR = ROUND((VLRTOT-VLRDESC)*(3/100),2)
		FROM	sankhya.TGFDIN DIN
				INNER JOIN sankhya.TGFITE ITE ON ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA AND CODIMP = 7
		WHERE	DIN.NUNOTA = @P_NUNOTA;

		/* resolvendo pis */
		UPDATE	DIN
		SET		BASE = (VLRTOT-VLRDESC),
				BASERED = (VLRTOT-VLRDESC),
				ALIQUOTA = 0.65,
				VALOR = ROUND((VLRTOT-VLRDESC)*(0.65/100),2)
		FROM	sankhya.TGFDIN DIN
				INNER JOIN sankhya.TGFITE ITE ON ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA AND CODIMP = 6
		WHERE	DIN.NUNOTA = @P_NUNOTA;

		/* 4. quando for kit, zerar o pis e cofins; */
		/* resolvendo o valor do pis e cofins para kits */
		UPDATE	DIN
		SET		VALOR = 0
		FROM	sankhya.TGFDIN DIN
				INNER JOIN sankhya.TGFITE ITE ON ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA AND USOPROD = 'R' AND CODVOL = 'KT'
		WHERE	DIN.NUNOTA = @P_NUNOTA
				AND CODIMP IN (6,7);

		/* 5. quando for reenvio, corrige os valores para ficar tudo zerado */
		UPDATE	DIN
		SET		VLRCRED=0,
				VLRDIFALDEST = 0,
				VLRDIFALREM=0,
				VLRFCP=0,
				PERCFCP=0,
				PERCPARTDIFAL=0,
				ALIQINTDEST=0
		FROM	sankhya.TGFDIN DIN
				INNER JOIN sankhya.TGFCAB CAB ON CAB.NUNOTA = DIN.NUNOTA
		WHERE	DIN.NUNOTA = @P_NUNOTA
				AND CAB.AD_BONIFICADO = 'S'
				AND VLRNOTA = 0
		UPDATE	sankhya.TGFCAB
		SET		VLRICMSFCP = 0,
				VLRICMSDIFALDEST = 0,
				VLRICMSDIFALREM = 0
		WHERE	NUNOTA = @P_NUNOTA
				AND AD_BONIFICADO = 'S'
				AND VLRNOTA = 0;
						   
		SET @P_SUCESSO = 'S';
END
