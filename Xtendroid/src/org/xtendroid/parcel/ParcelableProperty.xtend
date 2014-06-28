package org.xtendroid.parcel

import android.os.Parcel
import android.os.Parcelable.Creator
import java.util.List
import org.eclipse.xtend.lib.macro.AbstractClassProcessor
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.TransformationParticipant
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableEnumerationTypeDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableEnumerationValueDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableFieldDeclaration
import org.eclipse.xtend.lib.macro.declaration.Visibility
import org.json.JSONException
import org.xtendroid.json.JsonPropertyProcessor

//import org.eclipse.xtend.lib.macro.declaration.MutableEnumerationTypeDeclaration

@Active(ParcelableProcessor)
annotation AndroidParcelable {}

@Active(ParcelableEnumTypeProcessor)
annotation EnumType {}

@Active(ParcelableEnumValueProcessor)
annotation EnumValue {}

/**
 *  resources:
 * http://mobile.dzone.com/articles/using-android-parcel
 * http://blog.efftinge.de/2013/03/fun-with-active-annotations-my-little.html
 */

/**
 * 
 * Composable with @Property and probably @JSONProperty
 * 
 */

 /**
  * TODO on a separate project: turn on logging, @AndroidLog android.os.Log
  */

class ParcelableProcessor extends AbstractClassProcessor
{
	val static supportedPrimitiveScalarType= #{
		'java.lang.String' -> 'String'
		, 'byte' -> 'Byte' // writeByte, readByte
		, 'double' -> 'Double'
		, 'float' -> 'Float'
		, 'int' -> 'Int'
		, 'long' -> 'Long'
		, 'String' -> 'String'
	}
	
	val static supportedPrimitiveArrayType = #{
		'java.lang.String[]' -> 'StringArray'
		, 'boolean[]' -> 'BooleanArray'
		, 'byte[]' -> 'ByteArray'
		, 'double[]' -> 'DoubleArray'
		, 'float[]' -> 'FloatArray'
		, 'int[]' -> 'IntArray'
		, 'long[]' -> 'LongArray'
		, 'String[]' -> 'StringArray'
		, 'android.util.SparseBooleanArray' -> 'SparseBooleanArray'
	}
	
	val static unsupportedAbstractTypesAndSuggestedTypes = #{
		'java.lang.Byte' -> 'byte'
		, 'java.lang.Double' -> 'double'
		, 'java.lang.Float' -> 'float'
		, 'java.lang.Integer' -> 'int'
		, 'java.lang.Long' -> 'long'
		, 'java.lang.Boolean[]' -> 'boolean[]' // or: convert to SparseBooleanArray at the cost of more computational power
		, 'java.lang.Byte[]' -> 'byte[]'
		, 'java.lang.Char[]' -> 'char[]'
		, 'java.lang.Double[]' -> 'double[]'
		, 'java.lang.Float[]' -> 'float[]'
		, 'java.lang.Integer[]' -> 'int[]'
		, 'java.lang.Long[]' -> 'long[]'
	}
	
	/**
	 * 
	 * Marshalling code generator for common types
	 * 
	 */
	def mapTypeToWriteMethodBody(MutableFieldDeclaration f) '''
		«IF supportedPrimitiveScalarType.containsKey(f.type.name)»
			in.write«supportedPrimitiveScalarType.get(f.type.name)»(this.«f.simpleName»);
		«ELSEIF supportedPrimitiveArrayType.keySet.exists[ k | k.endsWith(f.type.name)]»
			in.write«supportedPrimitiveArrayType.get(f.type.name)»(this.«f.simpleName»);
		«ELSEIF "boolean".equals(f.type.name)»
			in.writeInt(this.«f.simpleName» ? 1 : 0);
		«ELSEIF "java.util.Date".equals(f.type.name)»
			in.writeLong(this.«f.simpleName».getTime());
		«ELSEIF f.type.name.startsWith("org.json.JSON")»
			in.writeString(this.«f.simpleName».toString());
		«ELSEIF f.type.name.startsWith('java.util.List')»
			«IF f.type.actualTypeArguments.head.name.equals('java.util.Date')»
				if («f.simpleName» != null)
				{
					long[] «f.simpleName»LongArray = new long[«f.simpleName».size()];
					for (int i=0; i<«f.simpleName».size(); i++)
					{
						«f.simpleName»LongArray[i] = ((java.util.Date) «f.simpleName».toArray()[i]).getTime();
					}
					in.writeLongArray(«f.simpleName»LongArray);
				}
			«ELSEIF f.type.actualTypeArguments.head.name.equals('java.lang.String')»
				in.writeStringList(this.«f.simpleName»);
			«ELSE»
				in.writeTypedList(this.«f.simpleName»);
			«ENDIF»
		«ELSEIF f.type.name.endsWith('[]')»
			«IF f.type.name.startsWith("java.util.Date")»
				if (this.«f.simpleName» != null)
				{
					long[] «f.simpleName»LongArray = new long[this.«f.simpleName».length];
					for (int i=0; i < this.«f.simpleName».length; i++)
					{
						«f.simpleName»LongArray[i] = this.«f.simpleName»[i].getTime();
					}
					in.writeLongArray(«f.simpleName»LongArray);
				}
			«ELSE»
				in.writeParcelableArray(this.«f.simpleName», flags);
			«ENDIF»
		«ELSE»
			in.writeParcelable(this.«f.simpleName», flags);
		«ENDIF»
	'''
	
	/**
	 * 
	 * Demarshalling code for common types
	 * 
	 */
	def mapTypeToReadMethodBody(MutableFieldDeclaration f) '''
		«IF supportedPrimitiveScalarType.containsKey(f.type.name)»
			this.«f.simpleName» = in.read«supportedPrimitiveScalarType.get(f.type.name)»();
		«ELSEIF supportedPrimitiveArrayType.containsKey(f.type.name)»
			this.«f.simpleName» = in.create«supportedPrimitiveArrayType.get(f.type.name)»();
		«ELSEIF "boolean".equals(f.type.name)»
			this.«f.simpleName» = in.readInt() > 0;
		«ELSEIF "java.util.Date".equals(f.type.name)»
			this.«f.simpleName» = new Date(in.readLong());
		«ELSEIF "org.json.JSONObject".equals(f.type.name)»
			this.«f.simpleName» = new JSONObject(in.readString());
		«ELSEIF "org.json.JSONArray".equals(f.type.name)»
			this.«f.simpleName» = new JSONArray(in.readString());
		«ELSEIF f.type.name.endsWith('[]')»
			«IF f.type.name.startsWith("java.util.Date")»
				long[] «f.simpleName»LongArray = in.createLongArray();
				if («f.simpleName»LongArray != null)
				{
					«f.simpleName» = new Date[«f.simpleName»LongArray.length];
					for (int i=0; i < «f.simpleName»LongArray.length; i++)
					{
						this.«f.simpleName»[i] = new Date(«f.simpleName»LongArray[i]);
					}
				}
			«ELSE»
				this.«f.simpleName» = («f.type.name») in.createTypedArray(«f.type.name».CREATOR);
			«ENDIF»
		«ELSEIF f.type.name.startsWith('java.util.List')»
			«IF f.type.actualTypeArguments.head.name.equals('java.util.Date')»
				long[] «f.simpleName»LongArray = in.createLongArray();
				if («f.simpleName»LongArray != null)
				{
					java.util.Date[] «f.simpleName»DateArray = new Date[«f.simpleName»LongArray.length];
					for (int i=0; i<«f.simpleName»LongArray.length; i++)
					{
						«f.simpleName»DateArray[i] = new Date(«f.simpleName»LongArray[i]);
					}
					«f.simpleName» = java.util.Arrays.asList(«f.simpleName»DateArray);
				}
			«ELSEIF f.type.actualTypeArguments.head.name.equals('java.lang.String')»
				in.readStringList(this.«f.simpleName»);
			«ELSE»
				in.readTypedList(this.«f.simpleName», «f.type.actualTypeArguments.head.name».CREATOR);
			«ENDIF»
		«ELSE»
			this.«f.simpleName» = («f.type.name») «f.type.name».CREATOR.createFromParcel(in);
		«ENDIF»
	'''
	
	override doTransform(MutableClassDeclaration clazz, extension TransformationContext context) {
		if (!clazz.implementedInterfaces.exists[i | "android.os.Parcelable".endsWith(i.name) ])
		{
			val interfaces = clazz.implementedInterfaces.join(', ')
			clazz.addError (String.format("To use @AndroidParcelable, %s must implement android.os.Parcelable, currently it implements: %s.", clazz.simpleName, if (interfaces.empty) 'nothing.' else interfaces))
		}
		
		val fields = clazz.declaredFields // .filter[findAnnotation(xtendPropertyAnnotation) != null]
		val jsonPropertyFieldDeclared = fields.exists[f | f.simpleName.equalsIgnoreCase(JsonPropertyProcessor.jsonObjectFieldName) && f.type.name.equalsIgnoreCase('org.json.JSONObject')]
		for (f : fields)
		{
			if (unsupportedAbstractTypesAndSuggestedTypes.keySet.contains(f.type.name))
			{
				f.addError (String.format("%s has the type %s, it may not be used with @AndroidParcelable. Use %s instead.", f.simpleName, f.type.name, ParcelableProcessor.unsupportedAbstractTypesAndSuggestedTypes.get(f.type.name)))
			}
			
			if (!jsonPropertyFieldDeclared && f.annotations.exists[a | a.annotationTypeDeclaration.simpleName.endsWith('JsonProperty') ])//.equals(JsonProperty.newAnnotationReference)])
			{
				f.addWarning (String.format("%s has certain fields that are annotated with @JsonProperty, you have to declare the %s field explicitly, initialized in the ctor as well to prevent data loss when passing the data object between Activities/Services etc.\nFor example:\n%s", f.declaringType.simpleName, JsonPropertyProcessor.jsonObjectFieldName,
				// the gist of the story is to explicitly declare a type like this
					'''
						@AndroidParcelable
						class C implements Parcelable
						{
							JSONObject «JsonPropertyProcessor.jsonObjectFieldName»
							
							@JsonProperty
							String meh
						}
					'''))
			}		
		}
		
		// @Override public int describeContents() { return 0; }
		clazz.addMethod("describeContents")  [
			returnType = int.newTypeReference
			addAnnotation(Override.newAnnotationReference)
			body = '''
				return 0;
			'''
		]
		

		clazz.addMethod("writeToParcel")  [
			returnType = void.newTypeReference
			addParameter('in', Parcel.newTypeReference)
			addParameter('flags', int.newTypeReference)
			addAnnotation(Override.newAnnotationReference)
			body = [ '''
				«fields.map[f | f.mapTypeToWriteMethodBody ].join()»
			''']
		]
		
		val parcelableCreatorTypeName = Creator.newTypeReference.simpleName
		clazz.addField("CREATOR") [
			static = true
			final = true
			type = Creator.newTypeReference
			visibility = Visibility.PUBLIC
			initializer = ['''
				new «parcelableCreatorTypeName»<«clazz.simpleName»>() {
					public «clazz.simpleName» createFromParcel(final Parcel in) {
						return new «clazz.simpleName»(in);
					} 
					
					public «clazz.simpleName»[] newArray(final int size) {
						return new «clazz.simpleName»[size];
					}
				}''']
		]			
		
		clazz.addConstructor[
			body = ['''
				// empty ctor
			''']
		]

		val exceptionsTypeRef = if (fields.exists[f|f.type.name.startsWith("org.json.JSON")])  #[ JSONException.newTypeReference() ] else #[]
		clazz.addConstructor[
			addParameter('in', Parcel.newTypeReference)
			body = ['''
				«IF exceptionsTypeRef.empty»
					readFromParcel(in);
				«ELSE»
					try
					{
						readFromParcel(in);
					}catch(JSONException e)
					{
						// TODO do error handling
						/*
						if (BuildConfig.DEBUG)
						{
							Log.e("«clazz.simpleName»", e.getLocalizedMessage());
						}
						*/
					}
				«ENDIF»
			''']
		]
		
		clazz.addMethod('readFromParcel') [
			addParameter('in', Parcel.newTypeReference)
			body = ['''
				«fields.map[f | f.mapTypeToReadMethodBody ].join()»
			''']
			exceptions = exceptionsTypeRef
			returnType = void.newTypeReference				
		]
	}
}

class ParcelableEnumTypeProcessor implements TransformationParticipant<MutableEnumerationTypeDeclaration>
{
	
	override doTransform(List<? extends MutableEnumerationTypeDeclaration> annotatedTargetElements, extension TransformationContext context) {
		for (enumType : annotatedTargetElements)
		{
			val enumTypeAnnotation = enumType.annotations.filter[a | a.annotationTypeDeclaration.simpleName.endsWith("AndroidParcelableEnumType")].head
			// get all values of enum annotation (class/primitive types)
			// then create a getter function for each class type,
			// create ctor for each class type
		}
	}
}

class ParcelableEnumValueProcessor implements TransformationParticipant<MutableEnumerationValueDeclaration>
{
	override doTransform(List<? extends MutableEnumerationValueDeclaration> annotatedTargetElements, extension TransformationContext context) {
		for (value : annotatedTargetElements)
		{
//			expand the enum types with values provided thru the annotation: @Value
		}
	}
}