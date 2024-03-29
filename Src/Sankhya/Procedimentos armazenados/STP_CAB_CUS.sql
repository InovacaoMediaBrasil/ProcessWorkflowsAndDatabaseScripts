USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CAB_CUS]    Script Date: 27/03/2017 08:54:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [sankhya].[STP_CAB_CUS] (
       @P_CODUSU INT,                -- Código do usuário logado
       @P_IDSESSAO VARCHAR(4000),    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       @P_QTDLINHAS INT,             -- Informa a quantidade de registros selecionados no momento da execução.
       @P_MENSAGEM VARCHAR(4000) OUT -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
DECLARE
       @FIELD_NUNOTA INT,
       @I INT,
       @CODPROD int,
       @CUSREP float
   
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

       SET @I = 1 -- A variável "I" representa o registro corrente.
       WHILE @I <= @P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
       BEGIN
           -- Para obter o valor dos campos utilize uma das seguintes funções:
           --     ACT_INT_FIELD (Retorna o valor de um campo tipo NUMÉRICO INTEIRO))
           --     ACT_DEC_FIELD (Retorna o valor de um campo tipo NUMÉRICO DECIMAL))
           --     ACT_TXT_FIELD (Retorna o valor de um campo tipo TEXTO),
           --     ACT_DTA_FIELD (Retorna o valor de um campo tipo DATA)
           -- Estas funções recebem 3 argumentos:
           --     ID DA SESSÃO - Identificador da execução (Obtido através do parâmetro P_IDSESSAO))
           --     NÚMERO DA LINHA - Relativo a qual linha selecionada.
           --     NOME DO CAMPO - Determina qual campo deve ser obtido.

           SET @FIELD_NUNOTA = SANKHYA.ACT_INT_FIELD(@P_IDSESSAO, @I, 'NUNOTA')

Declare curP cursor For

SELECT distinct ite.codprod, cus.CUSREP
FROM	sankhya.TGFCUS CUS
		INNER JOIN (SELECT	CODPROD, MAX(DTATUAL) AS MAXDATE
					FROM sankhya.TGFCUS GROUP BY CODPROD) CUSGRP
		ON CUS.CODPROD = CUSGRP.CODPROD AND CUS.DTATUAL = CUSGRP.MAXDATE
		INNER JOIN sankhya.TGFITE ITE ON (ITE.CODPROD = CUS.CODPROD)
WHERE	ITE.NUNOTA = @FIELD_NUNOTA;

OPEN curP 
Fetch Next From curP Into @codprod, @cusrep

	While @@Fetch_Status = 0 Begin

		UPDATE TGFITE SET VLRUNIT = @cusrep
		WHERE CODPROD = @CODPROD AND NUNOTA = @FIELD_NUNOTA


		FETCH NEXT FROM curP INTO @CODPROD, @CUSREP

		End -- End of Fetch

		Close curP
		Deallocate curP
			SET @I = @I + 1
	END

END
